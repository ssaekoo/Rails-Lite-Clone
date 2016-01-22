require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    conditions = params.map{|k, v| "#{k.to_s} = '#{v.to_s}'"}.join(' AND ')
    results = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{conditions}
    SQL
    results.map {|result| self.new(result)}
  end
end

class SQLObject
  extend Searchable
end
