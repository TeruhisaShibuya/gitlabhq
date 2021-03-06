class AddIndexToCiRunnersForIsShared < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    add_concurrent_index :ci_runners, :is_shared
  end

  def down
    if index_exists?(:ci_runners, :is_shared)
      remove_index :ci_runners, :is_shared
    end
  end
end
