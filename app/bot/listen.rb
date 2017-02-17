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
        # find the starting question
        @question = Question.starting
        sentMessageText = @question.text

        # if there are new lines, send as separate messages
        multipleTexts = sentMessageText.split(/\r\n/)
        if multipleTexts.size > 1
          sentMessageText = multipleTexts.pop
          multipleTexts.each do |question_text|
            if question_text != sentMessageText
              message.reply(text: question_text)
            end
          end
        end

        # send the last part of a multi line question OR the single line question
        message.reply(text: sentMessageText)

        # send the top stories
        user.send_top_stories(4)

        if @question.response && @question.response.text.blank? && @question.response.next_question.present?
          next_question = @question.response.next_question
          sentMessageText = next_question.text
          buttons = next_question.possible_answers.map do |pa|
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
        end
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

      when /our picks|highlights|major|picks/i
        shows = Show.where(major: true).order("date_time DESC").limit(4)
        if shows.any?
          sentMessageText = Content.find_by_label("our_picks").body
          replyMessageContents = { text: sentMessageText }
        else
          sentMessageText = Content.find_by_label("no_upcoming_shows").body
        end

      when /top stories|news|stories|top story|latest stories/i
        # subscribe to top stories
        user.send_top_stories(4)
        @question = Question.where(category: "top_stories", type: "yes_no").first
        sentMessageText = @question.text
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

      when /help/i
        sentMessageText = Content.find_by_label("help").body
        replyMessageContents = { text: sentMessageText }

        # default to looking up a brand
      else
        # Send both shows and articles
        if brand = Brand.where("title ilike ?", message.text.downcase).first
          shows_and_articles = brand.latest_content
          begin
            user.deliver_message_for(shows_and_articles)
          rescue => e
            puts "Failed replying to message because: #{e}"
          end

          # Failed finding a match for the brand entered
        else
          puts "Failed finding a matching brand for the text '#{message.text.downcase}'"
          sentMessageText = Content.find_by_label("unrecognised").body
          begin
            replyMessageContents = { text: "#{sentMessageText} '#{message.text}'" }
            message.reply(replyMessageContents)
            sent_message.update!(text: sentMessageText, sent_at: Time.now)
          rescue => e
            puts e
          end
        end
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

      # "All Shows"
      if @answer.action == "send_latest_shows"
        user.update!(subscribe_all_shows: true)
        if Show.past.any?
          shows = Show.past.order("date_time DESC").limit(4)
          begin
            user.deliver_message_for(shows)
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
        else
          sentMessageText = Content.find_by_label("no_latest_shows").body
          replyMessageContents = { text: sentMessageText }
        end

      elsif @answer.action == "send_major_shows"
        # respond with vogue picks of the shows
        user.update!(subscribe_major_shows: true)
        shows = Show.where(major: true).order("date_time DESC").limit(4)
        if !shows.any?
          sentMessageText = Content.find_by_label("no_latest_shows").body
          replyMessageContents = { text: sentMessageText }
        else
          begin
            user.deliver_message_for(shows)
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
        end

      elsif @answer.action == "follow_designer" && @answer.brand.present?
        shows_and_articles = @answer.brand.latest_content
        begin
          user.deliver_message_for(shows_and_articles)
        rescue => e
          puts "Failed replying to message because: #{e}"
        end

      elsif @answer.action == "send_help_text"
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

      elsif @answer.action == "subscribe_to_top_stories"
        # subscribe to top stories
        user.update!(subscribe_top_stories: true)
        sentMessageText = @answer.response.text
        replyMessageContents = { text: sentMessageText }
        postback.reply(replyMessageContents)

        # pause

        if @answer.response.next_question.present?
          @next_question = @answer.response.next_question
          if @next_question.possible_answers.any?
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
        end

      elsif @answer.action == "ask_next_question" && @answer.next_question.present?
        puts "Skipping to next question #{@answer.next_question.sort_order} #{@answer.next_question.text}"
        @next_question = @answer.next_question

        if @next_question.possible_answers.any?
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
        else
          sentMessageText = @next_question.text
          replyMessageContents = { text: sentMessageText }
        end
      end

    when /follow_designer/i
      @question = Question.where(category: "designers").first
        if @question.possible_answers.any?
          buttons = @question.possible_answers.map do |pa|
            { type: 'postback', title: pa.value, payload: "answer:#{pa.id}" }
          end
          sentMessageText = @question.text
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
        else
          sentMessageText = @question.text
          replyMessageContents = { text: sentMessageText }
        end

    when 'get_started'
      # find the starting question
      @question = Question.starting
      sentMessageText = @question.text

      # if there are new lines, send as separate messages
      multipleTexts = sentMessageText.split(/\r\n/)
      if multipleTexts.size > 1
        sentMessageText = multipleTexts.pop
        multipleTexts.each do |question_text|
          if question_text != sentMessageText
            postback.reply(text: question_text)
          end
        end
      end

      # send the last part of a multi line question OR the single line question
      postback.reply(text: sentMessageText)

      # send the top stories
      user.send_top_stories(4)

      if @question.response && @question.response.text.blank? && @question.response.next_question.present?
        next_question = @question.response.next_question
        sentMessageText = next_question.text
        buttons = next_question.possible_answers.map do |pa|
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
      end

    when /top_stories/i
      user.send_top_stories(4)

      @question = Question.where(category: "top_stories", type: "yes_no").first
      sentMessageText = @question.text
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

    # Send Major Shows
    when /OUR_PICKS|highlights/i
      shows = Show.where(major: true).order("date_time DESC").limit(4)
      if shows.any?
        sentMessageText = Content.find_by_label("our_picks").body
          begin
            user.deliver_message_for(shows)
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
      else
        sentMessageText = Content.find_by_label("no_upcoming_shows").body
        replyMessageContents = { text: sentMessageText }
      end

    when /latest shows|latest runway|runway|catwalk/i
      if Show.past.any?
        sentMessageText = Content.find_by_label("latest_shows").body
        shows = Show.past.order("date_time DESC").limit(3)
        begin
          user.deliver_message_for(shows)
        rescue => e
          puts "Failed replying to message #{postback.inspect} because: #{e}"
        end
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
        user.deliver_message_for(articles)
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
