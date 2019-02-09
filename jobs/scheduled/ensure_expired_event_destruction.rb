module Jobs
  class ::DiscourseCalendar::EnsuredExpiredEventDestruction < Jobs::Scheduled
    every 1.hour

    def execute(args)
      calendar_post_ids = PostCustomField
        .where(name: ::DiscourseCalendar::CALENDAR_CUSTOM_FIELD)
        .pluck(:post_id)

      calendar_topic_ids = Post
        .joins(:topic)
        .where(id: calendar_post_ids, post_number: 1)
        .where("NOT topics.closed AND NOT topics.archived")
        .pluck(:topic_id)

      PostCustomField
        .joins(post: :topic)
        .includes(post: :topic)
        .where("post_custom_fields.name = ?", ::DiscourseCalendar::CALENDAR_DETAILS_CUSTOM_FIELD)
        .where("topics.id IN (?)", calendar_topic_ids)
        .find_each do |pcf|

        details = JSON.parse(pcf.value)
        details.each do |post_number, (_, from, to, _, recurring)|
          return if recurring

          to_time = to ? Time.parse(to) : Time.parse(from) + 24.hours

          if (to_time + 1.hour) < Time.zone.now
            if post = pcf.post.topic.posts.find_by(post_number: post_number)
              PostDestroyer.new(Discourse.system_user, post).destroy
            end
          end
        end
      end
    end
  end
end
