namespace :forum2discourse do
  desc "Import from PunBB to Discourse Posts and Topics"
  task :import_punbb => :environment do
    exporter = Forum2Discourse::Exporter.create(:punbb, connection_string: 'mysql://root@127.0.0.1:3306/bytemark_punbb')
    puts "Importing #{exporter.topics.size} topics"
    # Override some settings to permit import
    originals = set_original_settings
    import_topics(exporter.topics)
    reset_settings_to(originals)
  end
end

def import_topics(topics)
  found_categories = []
  topics.each do |topic|
    next if topic.title.blank?
    puts "Importing '#{topic.title}'"
    u = User.admins.first
    g = Guardian.new(u)
    unless found_categories.include? topic.category
      Category.find_or_create_by_name(topic.category) do |c| # Create category if not exists first.
        c.user = u
      end
      found_categories << topic.category
    end
    discourse_topic = TopicCreator.new(u, g, topic.serialize).create
    import_topic_posts(discourse_topic, topic.posts)
  end
end

def import_topic_posts(discourse_topic, posts)
  posts.each do |post|
    data = post.serialize.merge({topic_id: discourse_topic.id})
    PostCreator.new(discourse_topic.user, data).create
  end
  puts "  Imported #{posts.size} posts"
end

def set_original_settings
  {
    max_word_length: SiteSetting.max_word_length,
    title_min_entropy: SiteSetting.title_min_entropy,
    min_topic_title_length: SiteSetting.min_topic_title_length,
    allow_duplicate_topic_titles: SiteSetting.allow_duplicate_topic_titles?
  }.tap do |_|
    SiteSetting.min_topic_title_length = 1
    SiteSetting.title_min_entropy = 0
    SiteSetting.max_word_length = 65535
    SiteSetting.allow_duplicate_topic_titles = true
  end
end

def reset_settings_to(originals)
  SiteSetting.max_word_length = originals[:max_word_length]
  SiteSetting.min_topic_title_length = originals[:min_topic_title_length]
  SiteSetting.title_min_entropy = originals[:title_min_entropy]
  SiteSetting.allow_duplicate_topic_titles = originals[:allow_duplicate_topic_titles]
end