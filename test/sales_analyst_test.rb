require_relative 'test_helper'

require_relative '../lib/sales_engine'
require_relative '../lib/sales_analyst'


require_relative '../lib/item_repository'
require_relative '../lib/merchant_repository'
require_relative '../lib/invoice_repository'
require_relative '../lib/invoice_item_repository'
require_relative '../lib/transaction_repository'
require_relative '../lib/customer_repository'

require_relative '../lib/invoice_item'



class SalesAnalystTest < Minitest::Test

  # ================================
  def setup
    hash = {
              :items         => "./data/items.csv",
              :merchants     => "./data/merchants.csv",
              :invoices      => "./data/invoices.csv",
              :invoice_items => "./data/invoice_items.csv",
              :transactions  => "./data/transactions.csv",
              :customers     => "./data/customers.csv"
            }
    # -- no data --
    se_new = SalesEngine.new({})
    @sa_new = SalesAnalyst.new(se_new)
    # -- CSV data --
    se_csv = SalesEngine.from_csv(hash)
    @sa_csv = SalesAnalyst.new(se_csv)
  end
  # ================================


  def test_it_exists
    assert_instance_of SalesAnalyst, @sa_new
    assert_instance_of SalesAnalyst, @sa_csv
  end

  def test_it_gets_attrubutes
    # ==== REPOs ====
    # -- Merchant --
    assert_instance_of MerchantRepository, @sa_csv.merchants
    assert_instance_of Merchant, @sa_csv.merchants.all[0]
    # -- Item --
    assert_instance_of ItemRepository, @sa_csv.items
    assert_instance_of Item, @sa_csv.items.all[0]
    # -- other --
    assert_instance_of InvoiceRepository, @sa_csv.invoices
    assert_instance_of InvoiceItemRepository, @sa_csv.invoice_items
    assert_instance_of TransactionRepository, @sa_csv.transactions
    assert_instance_of CustomerRepository, @sa_csv.customers
  end


  # --- General Methods ---

  def test_it_can_sum_values
    assert_equal 10.0, @sa_csv.sum([1, 2, 3, 4])
  end

  def test_it_can_average_an_array_of_values
    vals = [1, 2, 3, 4, 5]
    assert_equal 3.to_f, @sa_csv.average(vals)
  end

  def test_it_can_get_a_percentage
    found = 5
    all   = 10
    assert_equal 50.0, @sa_csv.percentage(found, all)
  end

  def test_it_does_standard_deviation
    vals = [1.0, 2.0, 3.0, 4.0, 5.0]
    sum = vals.inject(0) { |sum, val| sum += val }
    mean = sum / (vals.count).to_f
    assert_equal 1.58, @sa_csv.standard_deviation(vals, mean)
  end

  def test_it_gets_standard_deviation_measure
    # pairs with within/outside x std's of mean
    values = [1.0, 2.0, 3.0, 4.0, 5.0]
    sum = values.inject(0) { |sum, val| sum += val }
    mean = sum / (values.count).to_f
    # -- 1 STD above/below --
    std_1_high = mean + 1.58
    std_1_low  = mean - 1.58
    assert_equal std_1_high, @sa_csv.standard_dev_measure(values, 1)
    assert_equal std_1_low,  @sa_csv.standard_dev_measure(values, -1)
    # -- 2 STD above/below --
    std_2_high = mean + (1.58 * 2)
    std_2_low  = mean - (1.58 * 2)
    assert_equal std_2_high, @sa_csv.standard_dev_measure(values, 2)
    assert_equal std_2_low,  @sa_csv.standard_dev_measure(values, -2)
  end

  def test_if_finds_exceptional
    # This tests find_exceptional and
    # helper methods: exceptional_from_hash & exceptional_from_array
    # --- from hash ---
    hash = { "a" => [1, 2, 3], "b" => [1], "c" => [1, 2, 3, 4, 5, 6, 7]}
    hash_values = [3, 1, 7]
    stds = 1
    method = :count
    found = @sa_csv.find_exceptional(hash, hash_values, stds, method)
    top = {"c" => [1, 2, 3, 4, 5, 6, 7]}
    assert_instance_of Hash, found
    assert_equal top, found
    assert_equal top, @sa_csv.exceptional_from_hash(hash, hash_values, stds, method)
    # --- from Array ---
    array = @sa_csv.items.all
    array_values = array.map { |item| item.unit_price }
    stds = 2
    method = :unit_price
    found = @sa_csv.find_exceptional(array, array_values, stds, method)
    assert_equal found, @sa_csv.exceptional_from_array(array, array_values, stds, method)
    assert_instance_of Array, found
    assert_operator array.count, :>, found.count
    top = found.first
    std_high = @sa_csv.standard_dev_measure(array_values, 2)
    assert_instance_of Item, top
    assert_operator std_high, :<=, top.unit_price
  end


  # --- Item Repo Analysis Methods ---

  def test_it_creates_merchant_stores_by_id_and_item_collection
    qty_merch  = @sa_csv.merchants.all.count
    qty_stores = @sa_csv.merchant_stores.count
    assert_equal qty_merch, qty_stores
    assert_instance_of Hash, @sa_csv.merchant_stores
    assert_instance_of Array, @sa_csv.merchant_stores.values[0]
    assert_instance_of Item, @sa_csv.merchant_stores.values[0][0]
  end

  def test_it_can_create_an_array_of_the_counts_of_its_per_merchant
    groups = @sa_csv.merchant_stores
    values = @sa_csv.merchant_store_item_counts(groups)
    assert_instance_of Array, values
    qty_merch  = @sa_csv.merchants.all.count
    assert_equal qty_merch, values.count

    sum = values.inject(0) { |total, val| total += val}
    count = @sa_csv.items.all.count
    assert_equal count, sum
  end

  def test_it_gets_average_items_per_merchant
    assert_equal 2.88, @sa_csv.average_items_per_merchant
  end

  def test_it_gets_items_per_merchant_standard_deviation
    actual = @sa_csv.average_items_per_merchant_standard_deviation
    assert_equal 3.26, actual
  end

  def test_it_can_find_merchants_with_item_content_greater_than_one_std
    # --- returns a list of merchants --
    merchants = @sa_csv.merchants_with_high_item_count
    assert_instance_of Array, merchants
    assert_instance_of Merchant, merchants[0]
    # --- merchants are above 1 std ---
    # ------ merch 1 ------
    high_count = 2.88 + 3.26  # 1 std above
    merch_1 = merchants.first.id
    merch_1_items = @sa_csv.items.find_all_by_merchant_id(merch_1)
    assert_operator high_count, :<=, merch_1_items.count
    # ------ merch 2 ------
    merch_2 = merchants.last.id
    merch_2_items = @sa_csv.items.find_all_by_merchant_id(merch_2)
    assert_operator high_count, :<=, merch_2_items.count
  end

  def test_it_can_average_item_price_per_merchant
    id = 12334185
    all_merchant_items = @sa_csv.items.find_all_by_merchant_id(id)
    first_item = all_merchant_items[0]
    average_price = @sa_csv.average_item_price_for_merchant(id)
    assert_instance_of BigDecimal, average_price
    assert_operator 0, :<,  average_price
    refute_equal average_price, first_item.unit_price
  end

  def test_it_can_average_average_price_per_merchant
    id = 12334141
    one_average_price     = @sa_csv.average_item_price_for_merchant(id)
    average_average_price = @sa_csv.average_average_price_per_merchant
    assert_instance_of BigDecimal, average_average_price
    assert_operator 0, :<,  average_average_price
    refute_equal one_average_price, average_average_price
  end

  def test_it_gets_golden_items
    items = @sa_csv.golden_items
    assert_instance_of Array, items
    assert_instance_of Item, items[0]
    assert_operator @sa_csv.items.all.count, :>, items.count
    skip
    assert_operator 605303.51, :<=, items[0].unit_price
  end


  # --- Invoice Repo Analysis Methods ---

  def test_it_can_group_invoices_by_merchant_id
    groups = @sa_csv.invoices_grouped_by_merchant
    assert_instance_of Hash, groups
    id = groups.keys.first
    invoices = groups.values.first
    assert_instance_of Invoice, invoices.first
    assert_equal id, invoices.first.merchant_id
  end

  def test_it_can_count_invoices_per_merchant
    counts = @sa_csv.invoice_counts_per_merchant
    assert_instance_of Array, counts
    assert_instance_of Float, counts.first
  end

  def test_it_can_find_average_invoices_for_merchants
    assert_equal 10.49, @sa_csv.average_invoices_per_merchant
  end

  def test_it_can_find_the_standard_deviation_of_invoices_per_merchant
    assert_equal 3.29, @sa_csv.average_invoices_per_merchant_standard_deviation
  end

  def test_it_can_find_top_merchants_by_invoice_count
    # -- Return value --
    top = @sa_csv.top_merchants_by_invoice_count
    assert_instance_of Array, top
    assert_instance_of Merchant, top.first
    assert_operator top.count, :<, @sa_csv.merchants.all.count
    # -- verify a returned object --
    first_id = top.first.id
    groups = @sa_csv.invoices_grouped_by_merchant
    count = groups[first_id].count
    assert_operator 17.07, :<, count
  end

  def test_it_can_find_bottom_merchants_by_count
    # -- Return value --
    bottom = @sa_csv.bottom_merchants_by_invoice_count
    assert_instance_of Array, bottom
    assert_instance_of Merchant, bottom.first
    assert_operator bottom.count, :<, @sa_csv.merchants.all.count
    # -- verify a returned object --
    first_id = bottom.first.id
    groups = @sa_csv.invoices_grouped_by_merchant
    count = groups[first_id].count
    assert_operator 3.91, :>, count
  end

  def test_it_can_find_top_days_by_invoice_count_that_day
    top = @sa_csv.top_days_by_invoice_count
    assert_instance_of Array, top
    assert_equal "Wednesday", top.first
  end

  def test_it_can_find_the_status_of_all_invoices_as_a_percentage
    assert_equal 29.55, @sa_csv.invoice_status(:pending)
    assert_equal 56.95, @sa_csv.invoice_status(:shipped)
    assert_equal 13.5,  @sa_csv.invoice_status(:returned)
  end


  # --- Transaction Repo Analysis Methods ---

  def test_it_can_assess_if_an_invoice_was_paid_in_full
    id_with_a_success = 1752
    all_transactions_by_id = @sa_csv.transactions.find_all_by_invoice_id(1752)
    all_results = all_transactions_by_id.map { |trans| trans.result }
    has_fail = all_results.include?(:failed)
    has_success = all_results.include?(:success)
    assert_equal true, has_fail
    assert_equal true, has_success
    assert_equal true, @sa_csv.invoice_paid_in_full?( id_with_a_success )
  end

  def test_it_can_find_a_list_of_successful_invoice_items
    # -- Returned --> not successful --
    id = 25
    items = @sa_csv.invoice_items_of_successful_transactions( id )
    assert_nil items
    # -- Pending --> successful --
    id = 1
    items = @sa_csv.invoice_items_of_successful_transactions( id )
    assert_operator 1, :<=, items.count
    assert_instance_of InvoiceItem, items.first
    # -- Shipped --> successful --
    id = 2
    items = @sa_csv.invoice_items_of_successful_transactions( id )
    assert_operator 1, :<=, items.count
    assert_instance_of InvoiceItem, items.first
  end

  def test_it_can_total_invoice_charge
    id = 1
    assert_equal 21067.77, @sa_csv.invoice_total(id)
  end


  # --- Merchant Revenue Analysis Methods ---

  def test_it_gets_array_of_invoice_totals
    invoice_ids = [1, 2, 3]
    actual = @sa_csv.totals_by_invoice_collection(invoice_ids)
    assert_instance_of Array, actual
    assert_instance_of BigDecimal, actual.first
  end


  def test_it_gets_the_total_revenue_by_day
    date = "2009-02-07"
    revenue = @sa_csv.total_revenue_by_date(date)
    assert_equal 21067.77, revenue
  end

  def test_it_gets_the_top_x_or_20_merchants_by_revenue
    # --- default count ---
    top = @sa_csv.top_revenue_earners
    assert_instance_of Array, top
    assert_equal 20, top.count
    assert_instance_of Merchant, top.first
    # --- custom count ---
    skip
    top = @sa_csv.top_revenue_earners(40)
    assert_instance_of Array, top
    assert_equal 40, top.count
    assert_instance_of Merchant, top.first
  end

  def test_it_gets_all_merchants_with_pending_invoices
    expected = 467
    actual   = @sa_csv.merchants_with_pending_invoices
    assert_instance_of Array,    actual
    assert_instance_of Merchant, actual.first
    assert_operator @sa_csv.merchants.all.count, :>, actual.count
    skip
    @sa_csv.quick_stats
  end

  def test_it_finds_merchants_with_all_failed_transactions
    actual = @sa_csv.merchants_with_all_failed_transactions
    assert_instance_of Array,      actual
    assert_operator 12334105, :<=, actual.first
  end

  def test_it_finds_invoices_with_all_failed_transactions
    actual = @sa_csv.invoices_with_all_failed_transactions
    assert_instance_of Array,      actual
    assert_operator 4985, :>=,     actual.first
  end

  def test_if_finds_merchants_without_transactions
    actual = @sa_csv.merchants_without_transactions
    assert_instance_of Array,      actual
    assert_operator 12334105, :<=, actual.first
  end

  def test_it_gets_single_item_merchant_pairs
    actual = @sa_csv.single_item_merchant_pairs
    assert_instance_of Hash, actual
    assert_operator 1, :<, actual.keys.first
    all_ones = actual.values.all?{ |val| val == 1 }
    assert_equal true, all_ones
  end

  def test_it_gets_merchants_with_only_one_item
    # uses single merchant pairs
    actual = @sa_csv.merchants_with_only_one_item
    assert_instance_of Array, actual
    all_merch = actual.all?{ |val| val.class == Merchant }
    assert_equal true, all_merch
  end

end
