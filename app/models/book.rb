class Book < ActiveRecord::Base
  STATUSES = ['next', 'current','finished']
  RATES    = ['1', '2', '3', '4', '5'] 
  
  attr_accessor :new_status
  
  after_create  :create_media
  before_update :update_status!
  
  has_and_belongs_to_many :related_books, 
                          :class_name => 'Book', 
                          :foreign_key => 'related_id', 
                          :join_table => 'related_books',
                          :order => 'title ASC'

  named_scope :finished, :conditions => ["state = 'finished'"], :order => "finished_on"
  named_scope :current,  :conditions => ["state = 'current'"]
  named_scope :next,     :conditions => ["state = 'next'"]
  
  validates_presence_of :title,   :message => "can't be blank"
  validates_presence_of :url,     :message => "can't be blank"
  validates_presence_of :blurb,   :message => "can't be blank"
  validates_presence_of :author,  :message => "can't be blank"
  validates_numericality_of :pages, :message => "is not a number"

  validate :validate_url  
  
  has_attached_file :cover,
                    :resize_to => '184x246>', 
                    :styles => { :large => '123x164>', :medium => '74x98>', :small => '49x66>' },
                    :storage => :s3,
                    :s3_credentials => "#{RAILS_ROOT}/config/amazon_s3.yml",
                    :bucket => 'bookqueue-development',
                    :path => ":attachment/:id/:style.:extension"

  validates_attachment_thumbnails :cover
  
  acts_as_state_machine :initial => :next
  state :next
  state :current,  :enter  => Proc.new {|b| b.started_on  = Date.today; b.update_media("current")}
  state :finished, :enter  => Proc.new {|b| b.finished_on = Date.today
                                            b.days_taken  = b.calculate_days_taken
                                            b.update_media("finished")}
  
  event :finish do    
    transitions :from  => :current, :to => :finished
  end

  event :start_reading do
    transitions :from  => :next,     :to  => :current
    transitions :from  => :finished, :to  => :current
  end

  event :stop_reading do
    transitions :from  => :current, :to => :next
  end  
  
  def calculate_days_taken
    if self.finished_on && self.started_on
      (self.finished_on.to_date - self.started_on.to_date).to_i
    end
  end
  
  
  def update_media(state)
    post       = FeedItem.new
    post.title = "#{title}"
    case state
      when "next"
        post.body  = "'#{title}', by #{author} added to #{configatron.owner_name}'s book queue."
        status = TWITTER.status(:post, "'#{title}', by #{author} added to #{configatron.owner_name}'s book queue.") if configatron.twitter_use
      when "current"
        post.body  = "Started reading '#{title}', by #{author}"
        status = TWITTER.status(:post, "Started reading '#{title}', by #{author}") if configatron.twitter_use
      when "finished"
        taken = self.days_taken
        post.body  = "'#{title}', by #{author} - finished in #{days_taken} days"  
        status = TWITTER.status(:post, "'#{title}', by #{author} - finished in #{days_taken} days") if configatron.twitter_use
    end
    post.save
  end

  def update_status!
    case self.new_status
      when "current"
        self.start_reading!
      when "finished"
        self.finish!
      when "next"
        self.stop_reading!
    end
  end

  def create_media
    self.update_media("next")
  end
  
  private 

  def validate_url
    errors.add(:url) unless %w(200 301 302).include?(Book.status_code(self.url))
  end

  def self.status_code(url)
    regexp = url.match(/https?:\/\/([^\/]+)(.*)/)
    path = regexp[2].blank? ? '/' : regexp[2]
    Net::HTTP.start(regexp[1]) {|http| http.head(path).code}
  rescue
    nil
  end
end
