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

      @received_message = Message.log_it(message)
      @received_message.update(user: user) if @received_message.present?

      case message.text
      when /stop|unsubscribe|quit/i
        sentMessageText = Content.find_by_label("unsubscribe-are-you-sure").body
        buttons = [
          { type: 'postback', title: "Yes", payload: "unsubscribe:1" },
          { type: 'postback', title: "No", payload: "unsubscribe:0" }
        ]
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
        message.reply(replyMessageContents)
        if user && (user.subscriptions.any? || user.subscribe_top_stories || user.subscribe_all_shows || user.subscribe_major_shows)
          puts "* user #{user.id} has some subscriptions"
        else
          puts "* user #{user.id} has no subscriptions"
        end

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
          puts "Sending next question: #{next_question.sort_order} - #{next_question.text}"
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
          message.reply(replyMessageContents)
        else
          puts "Failed finding response for question id##{@question.id}"
        end

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
        message.reply(replyMessageContents)

      when /our picks|highlights|major|picks/i
        shows = Show.past.where(major: true).limit(4)
        if shows.any?
          sentMessageText = Content.find_by_label("highlighted-shows").body
          replyMessageContents = { text: sentMessageText }
        else
          sentMessageText = Content.find_by_label("no_highlighted-shows").body
        end
        replyMessageContents = { text: sentMessageText }
        message.reply(replyMessageContents)
        sent_message.update!(text: sentMessageText, sent_at: Time.now)

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
        message.reply(replyMessageContents)
        sent_message.update!(text: sentMessageText, sent_at: Time.now)

      when /help/i
        sentMessageText = Content.find_by_label("help").body
        replyMessageContents = { text: sentMessageText }
        message.reply(replyMessageContents)
        sent_message.update!(text: sentMessageText, sent_at: Time.now)

      else
        # default to looking up a brand
        # try to parse comma-delimited brand names
        begin
          brand_names = message.text.split(',').map(&:strip)
        rescue => e
          puts e
          brand_names = [message.text]
        end
        missing_brands = []
        all_brand_titles = Brand.pluck(:title)
        brand_names.each do |brand_name|

          brand_name.gsub!('.', '')
          brand_name.gsub!('-', '')
          # Send both shows and articles
          if matched_title = FuzzyMatch.new(all_brand_titles).find(brand_name)
            brand = Brand.where(title: matched_title).first
          else
            brand = Brand.where("title ilike ?", brand_name).first
          end

          if brand
            shows_and_articles = brand.latest_content
            begin
              if shows_and_articles && shows_and_articles.size > 0
                user.deliver_message_for(shows_and_articles)

                if existing_sub = user.subscriptions.where(brand: brand).first
                  existing_sub.update(sent_at: Time.now)
                  puts "Updated existing subscription: #{user.id} user + #{brand.id} brand + #{existing_sub.id} sub"
                elsif new_sub = user.subscriptions.create(brand: brand, signed_up_at: Time.now, sent_at: Time.now)
                  puts "Created new subscription: #{user.id} user + #{brand.id} brand + #{new_sub.id} sub"
                else
                  puts "Failed subscribing user: #{user.id} user + #{brand.id} brand"
                end
              else
                puts "No shows or articles for #{brand.title} found to send user #{user.id}"
              end

            rescue => e
              puts "Failed replying to message because: #{e}"
            end

            # Failed finding a match for the brand entered
          else

            puts "Failed finding a matching brand for the text '#{brand_name}'"
            missing_brands << brand_name
          end
        end

        # try matching against stored inputs/outputs last
        if missing_brands.any?
          if content = Content.find_match_for(message.text)
            sentMessageText = content.body
            message.reply({text: sentMessageText})
            sent_message.update!(text: sentMessageText, sent_at: Time.now)
          else
            sentMessageText = Content.find_by_label("unrecognised").body
            begin
              @received_message.update(unmatched_brand: true) if @received_message.present?
              replyMessageContents = { text: sentMessageText }
              message.reply(replyMessageContents)
              sent_message.update!(text: sentMessageText, sent_at: Time.now)
            rescue => e
              puts e
            end
          end
        elsif question = Question.where(category: "designers").first
          if question.response.present?
            sentMessageText = question.response.text + message.text
            replyMessageContents = { text: sentMessageText }
            message.reply(replyMessageContents)
            sent_message.update!(text: sentMessageText, sent_at: Time.now)
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

    @received_message = Message.log_it(postback)
    @received_message.update(user: user) if @received_message.present?

    replyMessageContents = nil
    sentMessageText = nil
    shows = []
    articles = []

    case postback.payload
    when /^unsubscribe:/i
      # parse the payload for answer id
      yes_or_no = postback.payload.split(":").last
      if yes_or_no == "1"
        user.subscriptions.delete_all
        user.update(subscribe_major_shows: false, subscribe_all_shows: false, subscribe_top_stories: false)
        puts "* user #{user.id} now subscribed to #{user.subscriptions.size} brands; top stories: #{user.subscribe_top_stories}; all shows: #{user.subscribe_all_shows}; major shows: #{user.subscribe_major_shows}"

        sentMessageText = Content.find_by_label("unsubscribed-confirmation").body
        replyMessageContents = { text: sentMessageText }
      else
        sentMessageText = Content.find_by_label("unsubscribed-changed-mind").body
        replyMessageContents = { text: sentMessageText }
      end

    when /^answer:/
      # parse the payload for answer id
      answer_id = postback.payload.split(":").last

      # look up the value for this answer to the question
      @answer = PossibleAnswer.find(answer_id)

      begin
        if appropriate_response = @answer.appropriate_response
          sentMessageText = appropriate_response.text
          replyMessageContents = { text: sentMessageText }
        end
      rescue => e
        puts e
      end

      # "All Shows"
      if @answer.action == "send_latest_shows"
        user.update!(subscribe_all_shows: true, subscribe_major_shows: false)
        if Show.past.any?
          shows = Show.past.limit(4)
          begin
            user.deliver_message_for(shows)
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
        else
          sentMessageText = Content.find_by_label("no-latest-shows").body
          replyMessageContents = { text: sentMessageText }
        end
        @next_question = if @answer.response && @answer.response.next_question.present?
                           @answer.response.next_question
                         elsif @answer.next_question.present?
                           @answer.next_question
                         end
        # pause

        if @next_question
          sentMessageText = @next_question.text
          if @next_question.possible_answers.any?
            buttons = @next_question.possible_answers.map do |pa|
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
          else
            sentMessageText = @next_question.text
            replyMessageContents = { text: sentMessageText }
          end
          # postback.reply(replyMessageContents)
          # sent_message.update!(text: sentMessageText, sent_at: Time.now)
        end

      elsif @answer.action == "send_major_shows"
        # respond with vogue picks of the shows
        user.update!(subscribe_major_shows: true, subscribe_all_shows: false)
        shows = Show.past.where(major: true).limit(4)
        if !shows.any?
          sentMessageText = Content.find_by_label("no-latest-shows").body
          replyMessageContents = { text: sentMessageText }
        else
          begin
            user.deliver_message_for(shows)
          rescue => e
            puts "Failed replying to message #{postback.inspect} because: #{e}"
          end
        end

        @next_question = if @answer.response && @answer.response.next_question.present?
                           @answer.response.next_question
                         elsif @answer.next_question.present?
                           @answer.next_question
                         end
        # pause

        if @next_question
          sentMessageText = @next_question.text
          if @next_question.possible_answers.any?
            buttons = @next_question.possible_answers.map do |pa|
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
          else
            sentMessageText = @next_question.text
            replyMessageContents = { text: sentMessageText }
          end
          # postback.reply(replyMessageContents)
          # sent_message.update!(text: sentMessageText, sent_at: Time.now)
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
        if @answer.response && @answer.response.text
          sentMessageText = @answer.response.text
          replyMessageContents = { text: sentMessageText }
          postback.reply(replyMessageContents)
        end

        @next_question = if @answer.response && @answer.response.next_question.present?
                           @answer.response.next_question
                         elsif @answer.next_question.present?
                           @answer.next_question
                         end
        # pause

        if @next_question
          sentMessageText = @next_question.text
          if @next_question.possible_answers.any?
            buttons = @next_question.possible_answers.map do |pa|
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
          else
            sentMessageText = @next_question.text
            replyMessageContents = { text: sentMessageText }
          end
          # postback.reply(replyMessageContents)
          # sent_message.update!(text: sentMessageText, sent_at: Time.now)
        end

      elsif @answer.action == "ask_next_question" && @answer.next_question.present?
        puts "Skipping to next question #{@answer.next_question.sort_order} #{@answer.next_question.text}"
        @next_question = @answer.next_question
        sentMessageText = @next_question.text
        if @next_question.possible_answers.any?
          buttons = @next_question.possible_answers.map do |pa|
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
        else
          replyMessageContents = { text: sentMessageText }
        end
        # postback.reply(replyMessageContents)
        # sent_message.update!(text: sentMessageText, sent_at: Time.now)
      end

    when /follow_designer/i
      @question = Question.where(category: "designers").first
      sentMessageText = @question.text
      if @question.possible_answers.any?
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
      user.update!(subscribe_major_shows: true)
      shows = Show.past.where(major: true).limit(4)
      if !shows.any?
        sentMessageText = Content.find_by_label("no-latest-shows").body
        replyMessageContents = { text: sentMessageText }
      else
        begin
          user.deliver_message_for(shows)
        rescue => e
          puts "Failed replying to message #{postback.inspect} because: #{e}"
        end
      end

    when /latest shows|latest runway|runway|catwalk|latest_shows/i
      shows = Show.past.limit(4)
      if shows && shows.any? && shows.size >= 1
        sentMessageText = Content.find_by_label("latest-shows").body
        begin
          user.deliver_message_for(shows)
        rescue => e
          puts "Failed replying to message #{postback.inspect} because: #{e}"
        end
      else
        sentMessageText = Content.find_by_label("no-latest-shows").body
        replyMessageContents = { text: sentMessageText }
      end

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
