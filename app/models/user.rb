# frozen_string_literal: true

class User < ApplicationRecord
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  attr_accessor :remember_token, :activation_token, :reset_token

  has_many :microposts, dependent: :destroy
  has_many :active_relationships, class_name: "Relationship",
                                  foreign_key: "follower_id", dependent: :destroy

  has_many :passive_relationships, class_name: "Relationship",
                                   foreign_key: "followed_id", dependent: :destroy

  has_many :following, through: :active_relationships, source: :followed
  has_many :followers, through: :passive_relationships, source: :follower

  validates :name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }

  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true

  # Use ActiveModel::SecurePassword
  has_secure_password

  scope :activated, -> { where(activated: true) }
  scope :inactivated, -> { where(activated: false) }

  def remember
    self.remember_token = SecureToken.create
    update_attribute(:remember_digest, SecureDigest.digest(remember_token))
  end

  def authenticated?(remember_token)
    return false if remember_digest.blank?
    SecureDigest.new(remember_digest).is_digest?(remember_token)
  end

  def forget
    update_attribute(:remember_digest, nil)
  end

  def inactivated?
    !activated?
  end

  # TODO: Summarize other `#authenticated?` methods
  def activation_authenticated?(activation_token)
    SecureDigest.new(activation_digest).is_digest?(activation_token)
  end

  def reset_authenticated?(reset_token)
    SecureDigest.new(reset_digest).is_digest?(reset_token)
  end

  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  def feeds
    scoped_posts = Micropost.includes(:user).recent.with_attached_picture
    scoped_posts.of_user(following).or(scoped_posts.of_user(self))
  end

  def follow(other)
    active_relationships.create(followed_id: other.id)
  end

  def unfollow(other)
    active_relationships.find_by(followed_id: other).destroy
  end

  def following?(other)
    following.include?(other)
  end

  def followed?(other)
    followed.include?(other)
  end
end
