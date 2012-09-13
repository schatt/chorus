class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.integer :author_id
      t.text    :body
      t.integer :event_id

      t.timestamps
    end
  end
end
