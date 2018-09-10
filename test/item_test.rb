require 'pry'
require 'minitest/autorun'
require 'minitest/pride'
require './lib/item'
require 'bigdecimal'

class ItemTest < Minitest::Test

  def setup
    # -- First Item's information --
    #          (from csv)
    # NOTE - The description is only an except.
    # NOTE - DO NOT try to match the description value (@repo.all[0].description)
    @headers = [:id, :created_at, :merchant_id, :name, :description, :unit_price, :updated_at]
    # --- CSVParse created hash set ---
    @hash = {
              :id             => 263395237,
              :name           => "510+ RealPush Icon Set",
              :description    => "You&#39;ve got a total socialmedia iconset!", # NOTE - excerpt!
              :unit_price     => "1200",
              :merchant_id    => "12334141",
              :created_at     => "2016-01-11 09:34:06 UTC",
              :updated_at     => "2007-06-04 21:35:10 UTC"
    }
    @item = Item.new(@hash)
    @big_decimal = BigDecimal.new(@hash[:unit_price], 4)
    @price_as_float = 1200.0000
    # -----------------------------------
  end


  def test_it_exists
    assert_instance_of Item, @item
  end

  def test_it_gets_attributes
    # -- Read Only --
    assert_equal @hash[:id], @item.id
    assert_equal @hash[:created_at], @item.created_at
    assert_equal @hash[:merchant_id], @item.merchant_id
    # -- Accessible --
    assert_equal @hash[:name], @item.name
    assert_equal @hash[:description], @item.description
    assert_equal @big_decimal, @item.unit_price
    assert_equal @hash[:updated_at], @item.updated_at
  end

  def test_it_can_get_unit_price_in_dollars
    assert_equal @price_as_float, @item.unit_price_to_dollars
  end

end
