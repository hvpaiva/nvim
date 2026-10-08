# frozen_string_literal: true

# A product line in the inventory, priced in cents.
class Item
  attr_reader :sku, :name, :price_cents, :quantity

  def initialize(sku:, name:, price_cents:, quantity: 0)
    @sku = sku
    @name = name
    @price_cents = price_cents
    @quantity = quantity
  end

  def total_cents
    price_cents * quantity
  end

  def in_stock?
    quantity.positive?
  end
end
