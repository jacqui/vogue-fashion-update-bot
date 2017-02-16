# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170216125206) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "articles", force: :cascade do |t|
    t.string   "title"
    t.string   "url"
    t.string   "publish_time"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "tag"
    t.integer  "sort_order"
    t.datetime "display_date"
    t.string   "image_uid"
    t.integer  "brand_id"
    t.index ["brand_id"], name: "index_articles_on_brand_id", using: :btree
  end

  create_table "brands", force: :cascade do |t|
    t.string   "title"
    t.string   "slug"
    t.string   "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "broadcasts", force: :cascade do |t|
    t.text     "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "broadcasts_users", id: false, force: :cascade do |t|
    t.integer "user_id",              null: false
    t.integer "broadcast_message_id", null: false
  end

  create_table "contents", force: :cascade do |t|
    t.string   "title"
    t.string   "label"
    t.text     "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversations", force: :cascade do |t|
    t.integer  "user_id"
    t.datetime "started_at"
    t.datetime "last_message_sent_at"
    t.text     "transcript"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["user_id"], name: "index_conversations_on_user_id", using: :btree
  end

  create_table "locations", force: :cascade do |t|
    t.string   "title"
    t.string   "uid"
    t.string   "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.string   "mid"
    t.string   "senderid"
    t.integer  "seq"
    t.datetime "sent_at"
    t.text     "text"
    t.text     "attachments"
    t.text     "quick_reply"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "notifications", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "article_id"
    t.integer  "brand_id"
    t.datetime "sent_at"
    t.boolean  "sent"
    t.integer  "show_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_notifications_on_article_id", using: :btree
    t.index ["brand_id"], name: "index_notifications_on_brand_id", using: :btree
    t.index ["show_id"], name: "index_notifications_on_show_id", using: :btree
    t.index ["user_id"], name: "index_notifications_on_user_id", using: :btree
  end

  create_table "possible_answers", force: :cascade do |t|
    t.integer  "question_id"
    t.string   "value"
    t.integer  "sort_order"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "brand_id"
    t.string   "category"
    t.string   "action"
    t.integer  "next_question_id"
    t.index ["brand_id"], name: "index_possible_answers_on_brand_id", using: :btree
    t.index ["question_id"], name: "index_possible_answers_on_question_id", using: :btree
  end

  create_table "questions", force: :cascade do |t|
    t.integer  "sort_order"
    t.string   "text"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "type"
    t.boolean  "followup",   default: false
    t.string   "category"
  end

  create_table "responses", force: :cascade do |t|
    t.integer  "question_id"
    t.integer  "possible_answer_id"
    t.text     "text"
    t.string   "category"
    t.integer  "quantity"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.integer  "next_question_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.string   "title"
    t.string   "uid"
    t.string   "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sent_messages", force: :cascade do |t|
    t.integer  "brand_id"
    t.integer  "user_id"
    t.integer  "article_id"
    t.integer  "show_id"
    t.datetime "sent_at"
    t.text     "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shows", force: :cascade do |t|
    t.string   "title"
    t.string   "uid"
    t.datetime "published_at"
    t.datetime "date_time"
    t.string   "slug"
    t.text     "review"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.integer  "location_id"
    t.integer  "brand_id"
    t.integer  "season_id"
    t.boolean  "major",        default: false
    t.string   "image_uid"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "brand_id"
    t.datetime "signed_up_at"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.datetime "sent_at"
    t.index ["brand_id"], name: "index_subscriptions_on_brand_id", using: :btree
    t.index ["user_id", "brand_id"], name: "index_subscriptions_on_user_id_and_brand_id", unique: true, using: :btree
    t.index ["user_id"], name: "index_subscriptions_on_user_id", using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.string   "fbid"
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.datetime "last_message_sent_at"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "gender"
    t.string   "locale"
    t.string   "timezone"
    t.text     "shows_subscription"
    t.boolean  "top_stories_subscription", default: false
  end

  add_foreign_key "articles", "brands"
  add_foreign_key "conversations", "users"
  add_foreign_key "notifications", "articles"
  add_foreign_key "notifications", "brands"
  add_foreign_key "notifications", "shows"
  add_foreign_key "notifications", "users"
  add_foreign_key "possible_answers", "questions"
end
