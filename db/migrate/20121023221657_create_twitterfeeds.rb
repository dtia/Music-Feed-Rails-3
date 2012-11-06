class CreateTwitterfeeds < ActiveRecord::Migration
  def change
    create_table :twitterfeeds do |t|
      t.string :text
      t.string :user
      t.string :video
      t.string :title

      t.timestamps
    end
  end
end
