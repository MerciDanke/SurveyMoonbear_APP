require 'sequel'

Sequel.migration do
  change do
    create_table(:surveys) do
      uuid        :id, primary_key: true
      foreign_key :owner_id, :accounts
      String      :origin_id, unique: true
      String      :title
      TrueClass   :start_flag, default: 0
    end
  end
end
