include Facebook::Messenger

if Rails.env.production?
  Facebook::Messenger::Subscriptions.subscribe(access_token: ENV['ACCESS_TOKEN'])

  Bot.on :message do |message|

    puts "Received '#{message.inspect}' from #{message.sender}"

    unless message.text.nil?
      sent_message = User.create_with_sent_message(message)
      user = sent_message.user
      if sender = user.get_sender_profile
        puts sender.inspect
        user.update( first_name: sender['first_name'],
                    last_name: sender['last_name'],
                    gender: sender['gender'])
      end


      @conversation = user.conversation

      replyMessageContents = nil
      sentMessageText = nil
      shows = []
      articles = []

      Message.log_it(message)

      case message.text
      when /start/i
        @question = Question.starting
        sentMessageText = @question.text

        multipleTexts = @question.text.split(/\r\n/)
        if multipleTexts.size > 1
          sentMessageText = multipleTexts.pop # set it to the last message text
          multipleTexts.each do |question_text|
            if question_text != sentMessageText
              message.reply(text: question_text)
            end
          end
        end

        buttons = @question.possible_answers.map do |pa|
          { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
        end
        replyMessageContents = { attachment: {
          type: 'template',
          payload: {
            template_type: 'button',
            text: sentMessageText,
            buttons: buttons
          }
        }
        }

      when /designers|settings/i
        sentMessageText = user.designers_following_text
        replyMessageContents = { text: sentMessageText }

      when /british vogue|vogue/i
        sentMessageText = "vogue.co.uk"
        replyMessageContents = {
          attachment: {
            type: 'template',
            payload: {
              template_type: 'button',
              text: 'Visit British Vogue for fashion news, backstage photos, fashion trends, catwalk videos, supermodel interviews, beauty trends and celebrity party photos.',
              buttons: [{
                type: "web_url",
                url: "http://www.vogue.co.uk/" + Article::URL_TRACKING_PARAMS,
                title: sentMessageText
              }]
            }
          }
        }

      when /upcoming shows|upcoming/i
        if Show.upcoming.any?
          sentMessageText = Content.find_by_label("upcoming_shows").body
          next_three = Show.upcoming.order("date_time ASC").limit(3)
          sentMessageText += next_three.map do |show|
            "#{show.title} at #{show.date_time.to_formatted_s(:long_ordinal)}"
          end.join(', ')
          replyMessageContents = { text: sentMessageText }
        else
          sentMessageText = Content.find_by_label("no_upcoming_shows").body
          replyMessageContents = { text: sentMessageText }
        end

      when /our picks|highlights|best/i
        shows = Show.where(major: true).order("date_time DESC").limit(4)
        if shows.any?
          sentMessageText = Content.find_by_label("our_picks").body
          replyMessageContents = { text: sentMessageText }
        else
          sentMessageText = Content.find_by_label("no_upcoming_shows").body
        end

      when /top stories|news|stories|top story|latest stories/i
        # subscribe to top stories
        user.top_stories_subscription = true
        user.save

        user.send_top_stories(4)

      when /help/i
        sentMessageText = Content.find_by_label("help").body
        replyMessageContents = { text: sentMessageText }
      else
        if brand = Brand.where("title ilike ?", message.text.downcase).first
          # TODO: add a followup question
          brand_question = Question.where(category: "designers").first
          if brand_question && brand_question.possible_answers.any?
            buttons = brand_question.possible_answers.map do |pa|
              { type: 'postback', title: pa.value, payload: "brand:#{brand.id}:answer:#{pa.id}" }
            end
            sentMessageText = brand_question.text
            replyMessageContents = {
              attachment: {
                type: 'template',
                payload: {
                  template_type: 'button',
                  text: sentMessageText,
                  buttons: buttons
                }
              }
            }

            # Failed finding possible set answers for the question about brands
          elsif brand_question
            sentMessageText = brand_question.text
            replyMessageContents = { text: brand_question.text }

            # Failed finding the brand question at all, fallback to content
          else
            sentMessageText = Content.find_by_label("brand_question").body
          end

          # Failed finding a match for the brand entered
        else
          puts "Failed finding a matching brand for the text '#{message.text.downcase}'"
          sentMessageText = Content.find_by_label("unrecognised").body
          begin
            replyMessageContents = { text: "#{sentMessageText} '#{message.text}'" }
          rescue => e
            puts e
          end
        end
      end

      begin
        if shows.any?
          user.deliver_message_for(shows, "View the Show")
        elsif articles.any?
          user.deliver_message_for(articles, "View the Article")
        else
          message.reply(replyMessageContents)
          sent_message.update!(text: sentMessageText, sent_at: Time.now)
        end
      rescue => e
        puts "Failed replying to message #{message.inspect} because: #{e}"
      end
    end
  end

  Bot.on :postback do |postback|
    puts "Received postback #{postback.inspect} from #{postback.sender}"

    sent_message = User.create_with_sent_message(postback)
    user = sent_message.user

    @conversation = user.conversation
    puts "Convo: #{@conversation.id}"

    Message.log_it(postback)

    replyMessageContents = nil
    sentMessageText = nil
    shows = []
    articles = []

    case postback.payload

    when /^brand:/
      # parse the payload for brand and answer id
      brand_id = postback.payload.split(":")[1]
      answer_id = postback.payload.split(":").last
      brand = Brand.find(brand_id)
      answer = PossibleAnswer.find(answer_id)

      if brand && answer
        puts "found brand: #{brand.title}"
        puts "found answer: #{answer.action} #{answer.id}"

        if answer.action == "send_show_info"
          # find show information and send it
          shows = brand.shows.order("date_time DESC").limit(4)
          if !shows.any?
            sentMessageText = Content.find_by_label("no_shows_for_brand").body
            replyMessageContents = { text: sentMessageText }
          end
        end

        if answer.action == "send_latest_news"
          articles = brand.articles.order("created_at DESC").limit(4)
          if !articles.any?
            sentMessageText = Content.find_by_label("no_shows_for_brand").body
            replyMessageContents = { text: sentMessageText }
          end
        end

      else
        sentMessageText = Content.find_by_label("unrecognised").body
        replyMessageContents = { text: sentMessageText }
      end

    when /^answer:/
      # parse the payload for answer id
      answer_id = postback.payload.split(":").last

      # look up the value for this answer to the question
      @answer = PossibleAnswer.find(answer_id)

      begin
        appropriate_response = @answer.appropriate_response
        sentMessageText = appropriate_response.text
        replyMessageContents = { text: sentMessageText }

      rescue => e
        puts e
      end

      if @answer.category == "runway_shows" && @answer.action == "send_latest_shows"
        # respond with the most recent shows
        puts "*** SEND LATEST SHOWS ***"
        if Show.past.any?
          sentMessageText = Content.find_by_label("latest_shows").body
          shows = Show.past.order("date_time DESC").limit(3)
          begin
            user.deliver_message_for(shows, "View the Show")
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
        else
          sentMessageText = Content.find_by_label("no_latest_shows").body
          replyMessageContents = { text: sentMessageText }
        end

      elsif @answer.category == "runway_shows" && @answer.action == "send_vogue_picks_shows"
        # respond with vogue picks of the shows
        shows = Show.where(major: true).order("date_time DESC").limit(4)
        if !shows.any?
          sentMessageText = Content.find_by_label("no_upcoming_shows").body
          replyMessageContents = { text: sentMessageText }
        else
          begin
            user.deliver_message_for(shows, "View the Show")
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
        end

      elsif @answer.question.category == "top_stories" && @answer.action == "subscribe_to_top_stories"
        # subscribe to top stories
        user.top_stories_subscription = true
        user.save

        user.send_top_stories(4)
      end

      @next_question = if @answer.action == "skip_to_next_question" && @answer.next_question_id.present?
                         puts "Skipping to next question #{@answer.next_question_id}"
                         Question.find(@answer.next_question_id)
                       elsif appropriate_response.next_question.present?
                         puts " Found the next question for response ##{appropriate_response.id}: #{appropriate_response.next_question.id}"
                         appropriate_response.next_question
                       else
                         puts " Using the next question for answer ##{@answer.id}: #{@answer.question.next.id}"
                         # lookup the next question
                         @answer.question.next
                       end

      if @next_question && @next_question.possible_answers.any?
        buttons = @next_question.possible_answers.map do |pa|
          { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
        end
        sentMessageText = @next_question.text
        replyMessageContents = {
          attachment: {
            type: 'template',
            payload: {
              template_type: 'button',
              text: sentMessageText,
              buttons: buttons
            }
          }
        }
      elsif @next_question
        sentMessageText = @next_question.text
        replyMessageContents = { text: sentMessageText }
      end

    when /my-designers|settings|designers|prefs|preferences|follow_a_designer/i
      sentMessageText = user.designers_following_text
      replyMessageContents = { text: sentMessageText }

    when 'get_started'
      @question = Question.starting
      sentMessageText = @question.text
      multipleTexts = sentMessageText.split(/\r\n/)
      if multipleTexts.size > 1
        sentMessageText = multipleTexts.pop
        multipleTexts.each do |question_text|
          if question_text != sentMessageText
            postback.reply(text: question_text)
          end
        end
      end
      buttons = @question.possible_answers.map do |pa|
        { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
      end
      replyMessageContents = {
        attachment: {
          type: 'template',
          payload: {
            template_type: 'button',
            text: sentMessageText,
            buttons: buttons
          }
        }
      }

    when /top_stories/i
      user.top_stories_subscription = true
      user.save!
      user.send_top_stories(4)

    when /OUR_PICKS|highlights/i
      shows = Show.where(major: true).order("date_time DESC").limit(4)
      if shows.any?
        sentMessageText = Content.find_by_label("our_picks").body
      else
        sentMessageText = Content.find_by_label("no_upcoming_shows").body
        replyMessageContents = { text: sentMessageText }
      end

    when /latest shows|latest runway|runway|catwalk/i
      if Show.past.any?
        sentMessageText = Content.find_by_label("latest_shows").body
        shows = Show.past.order("date_time DESC").limit(3)
      else
        sentMessageText = Content.find_by_label("no_latest_shows").body
        replyMessageContents = { text: sentMessageText }
      end

    when /upcoming/i
      if Show.upcoming.any?
        sentMessageText = Content.find_by_label("upcoming_shows").body + " "
        next_three = Show.upcoming.order("date_time ASC").limit(3)
        sentMessageText += next_three.map do |show|
          "#{show.title} at #{show.date_time.to_formatted_s(:long_ordinal)}"
        end.join(', ')
      else
        sentMessageText = Content.find_by_label("no_upcoming_shows").body
      end
      replyMessageContents = { text: sentMessageText }

    when /help/i
      sentMessageText = Content.find_by_label("help").body
      multipleTexts = sentMessageText.split(/\r\n/)
      if multipleTexts.size > 1
        sentMessageText = multipleTexts.pop
        multipleTexts.each do |question_text|
          if question_text != sentMessageText
            postback.reply(text: question_text)
          end
        end
      end
      replyMessageContents = { text: sentMessageText }

    else
      sentMessageText = Content.find_by_label("unrecognised").body
      replyMessageContents = { text: sentMessageText }
    end

    begin
      if articles.any?
        user.deliver_message_for(articles, "View the Article")
      else
        postback.reply(replyMessageContents)
        sent_message.update!(text: sentMessageText, sent_at: Time.now)
      end
    rescue => e
      puts "Failed replying to message #{postback.inspect} because: #{e}"
    end
    @conversation.update(last_message_sent_at: Time.now)
  end

  Bot.on :delivery do |delivery|
    puts "Delivered message(s) #{delivery.ids}"
  end

end
