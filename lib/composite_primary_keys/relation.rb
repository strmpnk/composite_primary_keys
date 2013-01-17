class ActiveRecord::Relation

  define_singleton_method(:new_without_composite_check, method(:new).unbind)

  def self.new(klass, table, &b)
    raise "WHAT?" if self == CompositePrimaryKeys::ActiveRecord::Relation
    obj = klass.composite? ?
      CompositePrimaryKeys::ActiveRecord::Relation.new(klass, table, &b) :
      new_without_composite_check(klass, table, &b)
    obj
  end

end

class CompositePrimaryKeys::ActiveRecord::Relation < ActiveRecord::Relation
  include CompositePrimaryKeys::ActiveRecord::Batches
  include CompositePrimaryKeys::ActiveRecord::Calculations
  include CompositePrimaryKeys::ActiveRecord::FinderMethods
  include CompositePrimaryKeys::ActiveRecord::QueryMethods

  # Restore the old constructor so we don't go into an infinite loop
  define_singleton_method(:new, method(:new_without_composite_check).unbind)

  def delete(id_or_array)
    if ActiveRecord::IdentityMap.enabled?
      ActiveRecord::IdentityMap.remove_by_id(self.symbolized_base_class, id_or_array)
    end
    # Without CPK:
    # where(primary_key => id_or_array).delete_all
    id_or_array = if id_or_array.kind_of?(CompositePrimaryKeys::CompositeKeys)
      [id_or_array]
    else
      Array(id_or_array)
    end
    id_or_array.each do |id|
      where(cpk_id_predicate(table, self.primary_key, id)).delete_all
    end
  end

  def destroy(id_or_array)
    # Without CPK:
    #if id.is_a?(Array)
    #  id.map { |one_id| destroy(one_id) }
    #else
    #  find(id).destroy
    #end
    id_or_array = if id_or_array.kind_of?(CompositePrimaryKeys::CompositeKeys)
      [id_or_array]
    else
      Array(id_or_array)
    end
    id_or_array.each do |id|
      where(cpk_id_predicate(table, self.primary_key, id)).each do |record|
        record.destroy
      end
    end
  end

  def where_values_hash
    # CPK adds this so that it finds the Equality nodes beneath the And node:
    nodes_from_and = with_default_scope
      .where_values.grep(Arel::Nodes::And)
      .map {|and_node| and_node.children.grep(Arel::Nodes::Equality)}
      .flatten
    equalities = (nodes_from_and + with_default_scope.where_values.grep(Arel::Nodes::Equality))
      .find_all {|node| node.left.relation.name == table_name}
    hash = {}
    equalities.each do |where|
      hash[where.left.name] = where.right
    end
    hash
  end

end
