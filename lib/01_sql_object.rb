require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    @columns = DBConnection.execute2(<<-SQL).first.map(&:to_sym)
      SELECT *
      FROM #{self.table_name}
      LIMIT 0
    SQL
  end

  def self.finalize!
    self.columns.each do |column|
      define_method(column) do
        self.attributes[column]
      end
      define_method("#{column}=") do |val|
        self.attributes[column] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT *
      FROM #{self.table_name}
    SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map {|result| self.new(result)}
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id).first
      SELECT *
      FROM "#{table_name}"
      WHERE id = ?
    SQL
    return nil if result.nil?
    self.new(result)
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      raise "unknown attribute '#{attr_name}'" if !self.class.columns.include?(attr_name.to_sym)
      send("#{attr_name.to_sym}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map{|column| attributes[column]}
  end

  def insert
    col_names = self.class.columns.drop(1).join(", ")
    question_marks = (["?"] * (self.class.columns.length - 1)).join(", ")
    attribute_vals = attribute_values.drop(1)
    DBConnection.execute(<<-SQL, *attribute_vals )
      INSERT INTO
        #{self.class.table_name}(#{col_names})
      VALUES
        (#{question_marks})
    SQL
    send(:id=, self.class.find(DBConnection.last_insert_row_id).id)
  end

  def update
    col_names = self.class.columns.drop(1).join(" = ?, ").concat(" = ?")
    id = attribute_values.first
    attribute_vals = attribute_values.drop(1)
    DBConnection.execute(<<-SQL, *attribute_vals)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_names}
      WHERE
        id = #{id}
    SQL
  end

  def save
    if attribute_values.first.nil?
      insert
    else
      update
    end
  end
end
