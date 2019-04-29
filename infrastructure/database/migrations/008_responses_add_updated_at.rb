require 'sequel'

Sequel.migration do
  change do
    alter_table(:responses) do
      add_column :updated_at, Time, null: true, if_not_exists: true
    end
  end
end
