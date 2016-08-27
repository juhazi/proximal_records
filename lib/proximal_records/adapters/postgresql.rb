module ProximalRecords
  module Adapters
    module Postgresql
      def proximal_records(scope)
        klass = self.class

        orders = scope.orders.join(', ')

        orders = "OVER(#{"ORDER BY #{orders}" if orders.present?})"
        primary_key = "#{klass.table_name}.#{klass.primary_key}"

        scope_with_default_select = if scope.select_values.blank?
          # AR will replace default star select unless there's
          # atleast one select used
          scope.select(klass.arel_table[Arel.star])
        else
          # AR will append selects if any are defined previously
          scope
        end

        with_near_by = scope_with_default_select.select <<-EOSQL.squish
          LAG(#{primary_key}) #{orders} AS previous_id,
          LEAD(#{primary_key}) #{orders} AS next_id
        EOSQL

        scope_query = with_near_by.to_sql
        a = klass
          .unscoped
          .select('z.*')
          .from("(#{scope_query}) z")
          .where(z: {klass.primary_key => id})
          .order('z.id ASC')
          .limit(1)
          .first

        [
          (klass.find_by_id(a.previous_id)),
          (klass.find_by_id(a.next_id))
        ]
      end
    end
  end
end
