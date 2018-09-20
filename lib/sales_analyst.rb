require 'pry'

require_relative 'finderclass'
require_relative 'quick_stats'
require_relative 'sa_math'
require_relative 'sa_collections'

class SalesAnalyst
  include QuickStats
  include SAMath
  include SACollections



  attr_reader :merchants,
              :items,
              :invoices,
              :invoice_items,
              :transactions,
              :customers

  def initialize(sales_engine)
    @engine = sales_engine

    @merchants     = @engine.merchants
    @items         = @engine.items
    @invoices      = @engine.invoices
    @invoice_items = @engine.invoice_items
    @transactions  = @engine.transactions
    @customers     = @engine.customers
  end


  # --- Item Repo Analysis Methods ---

  def average_items_per_merchant
    groups = merchant_stores
    vals   = merchant_store_item_counts(groups)
    mean   = average(vals)
    return mean.round(2)
  end

  def average_items_per_merchant_standard_deviation
    mean   = average_items_per_merchant
    groups = merchant_stores
    vals   = merchant_store_item_counts(groups)
    std    = standard_deviation(vals, mean)
  end

  def merchants_with_high_item_count # find all merchants > one std of items
    groups    = merchant_stores
    values    = merchant_store_item_counts(groups)
    all_above = find_exceptional(groups, values, 1, :count)
    merch_ids = all_above.keys
    list      = merchants_by_id_collection(merch_ids)
    return list
  end

  def average_item_price_for_merchant(id)
    group = @items.find_all_by_merchant_id(id)
    total = sum(group, :unit_price)
    count = group.count
    mean  = (total / count).round(2)
  end   # returns big decimal

  def average_average_price_per_merchant
    repo     = @merchants.all
    ids      = FinderClass.make_array(repo, :id)
    averages = ids.map { |id| average_item_price_for_merchant(id) }
    mean     = average(averages).round(2)
    mean     = BigDecimal(mean, 5)
  end   # returns a big decimal

  def golden_items # items with prices above 2 std of average price
    prices   = FinderClass.make_array(@items.all, :unit_price)
    above    = find_exceptional(@items.all, prices, 2, :unit_price)
  end


  # --- Invoice Repo Analysis Methods ---

  def invoice_counts_per_merchant
    groups = invoices_grouped_by_merchant
    counts = groups.map { |id, invoices| invoices.count.to_f }
  end

  def average_invoices_per_merchant
    counts = invoice_counts_per_merchant
    mean   = average(counts).round(2)
  end

  def average_invoices_per_merchant_standard_deviation
    counts = invoice_counts_per_merchant
    mean   = average_invoices_per_merchant
    std    = standard_deviation(counts, mean).round(2)
  end

  def top_merchants_by_invoice_count  # two standard deviations above the mean
    groups        = invoices_grouped_by_merchant
    counts        = invoice_counts_per_merchant
    top           = find_exceptional(groups, counts, 2, :count)
    merch_ids     = top.keys
    top_merchants = merchants_by_id_collection(merch_ids)
  end

  def bottom_merchants_by_invoice_count  # two standard deviations below the mean
    groups           = invoices_grouped_by_merchant
    counts           = invoice_counts_per_merchant
    worst            = find_exceptional(groups, counts, -2, :count)
    merch_ids        = worst.keys
    bottom_merchants = merchants_by_id_collection(merch_ids)
  end

  def top_days_by_invoice_count
    groups      = @invoices.all.group_by { |invoice| invoice.created_at.wday}
    values      = FinderClass.make_array(groups.values, :count)
    top         = find_exceptional(groups, values, 1, :count)
    top_as_word = top.keys.map { |day| FinderClass.day_of_week(day) }
  end

  def invoice_status(status)
    all     = @invoices.all.count.to_f
    found   = @invoices.find_all_by_status(status).count
    percent = percentage(found, all).round(2)
  end


  # --- Transaction Repo Analysis Methods ---

  def invoice_paid_in_full?(invoice_id) # Paid in full if t/f
    sale = @transactions.find_all_by_invoice_id(invoice_id)
    sale.any? { |trans| trans.result == :success }
  end

  def invoice_items_of_successful_transactions(invoice_id)
    sold             = invoice_paid_in_full?(invoice_id)
    items_by_invoice = @invoice_items.find_all_by_invoice_id(invoice_id) if sold
  end

  def invoice_total(invoice_id)
    items_by_invoice = invoice_items_of_successful_transactions(invoice_id)
    items_by_invoice.inject(0){|sum, item|
      sum += revenue(item)
    } if items_by_invoice
  end

  def revenue(invoice_item)
    invoice_item.quantity * invoice_item.unit_price
  end


  # --- Merchant Revenue Analysis Methods ---

  def totals_by_invoice_collection(invoice_ids)
    invoice_ids.map{ |id| invoice_total(id) }
  end

  def total_revenue_by_date(date)
    day_invoices = FinderClass.find_by_all_by_date(@invoices.all, :created_at, date)
    inv_ids      = FinderClass.make_array(day_invoices, :id).flatten
    inv_costs    = totals_by_invoice_collection(inv_ids)
    total        = sum(inv_costs)
  end

  def top_revenue_earners(x = 20)
    hash       = invoices_grouped_by_merchant
    hash.each { |id, invs|
      inv_ids  = FinderClass.make_array(invs, :id)
      hash[id] = totals_by_invoice_collection(inv_ids).compact
    }
    hash.each { |id, costs| hash[id] = sum(costs) }
    top_ids    = hash.max_by(x) { |key, cost| cost}.to_h.keys
    list       = merchants_by_id_collection(top_ids)
  end


  # Call to see how merchants_with_pending_invoices was determined
  # uses QuickStats  -- how do you test these outside SalesAnalystTest ?
  def quick_stats
    puts ""; merchant_stats
  end

  # via invoices that don't have transactions or have all failed tranactions
  def merchants_with_pending_invoices
    failed    = merchants_with_all_failed_transactions
    missing   = merchants_without_transactions
    combo     = [failed, missing].flatten.uniq
    merchants = combo.map { |id| @merchants.find_by_id(id) }
  end

  def merchants_with_all_failed_transactions
    inv_ids   = invoices_with_all_failed_transactions
    invs      = inv_ids.map { |id| @invoices.find_by_id(id) }
    merch_ids = collection_by_merchant_id(invs).keys
  end

  def invoices_with_all_failed_transactions
    results = transaction_results_by_invoices
    inv_ids = results.find_all { |inv_id, results|
      results.all?{ |res| res == :failed }
    }.to_h.keys.uniq
  end

  def merchants_without_transactions
    invs = invoices_have_transactions(false)
    collection_by_merchant_id(invs).keys
  end

  def single_item_merchant_pairs
    groups = merchant_stores
    groups.each{ |id, items| groups[id] = items.count }
    ones   = groups.find_all { |id, count| count == 1 }.to_h
  end

  def merchants_with_only_one_item
    ids    = single_item_merchant_pairs.keys
    merchs = merchants_by_id_collection(ids)
  end

  def merchants_with_only_one_item_registered_in_month(word)
    month  = FinderClass.month_from_word(word).to_i
    shops  = merchants_with_only_one_item
    groups = shops.group_by { |shop| shop.created_at.month }
    list   = groups[month]
  end

  def revenue_by_merchant(merchant_id)
    merch_invs = @invoices.find_all_by_merchant_id(merchant_id)
    inv_items  = merch_invs.map { |inv| invoice_total(inv.id) }.compact
    sum        = sum(inv_items)
  end

  def merchants_ranked_by_revenue
    ranked = @merchants.all.group_by { |merch| revenue_by_merchant(merch.id) }
    count  = ranked.count
    sorted = ranked.max_by(count) { |rev, merch| rev }.to_h
    sorted = sorted.values.flatten
  end

  # TO DO - Test Me
  def quantity_by_item_id(hash)
    hash.each { |item_id, inv_items|
      hash[item_id] = sum(inv_items, :quantity)
    }; return hash
  end

  # TO DO - Test Me
  def successful_invoices_items_by_invoice_collection(invoices)
    invoices.map { |inv| invoice_items_of_successful_transactions(inv.id) }
  end

  def most_sold_item_for_merchant(merchant_id)
    invs = @invoices.find_all_by_merchant_id(merchant_id)
    inv_items = successful_invoices_items_by_invoice_collection(invs)
    inv_items = inv_items.flatten.compact
    groups    = invoice_items_grouped_by_item(inv_items)
    groups    = quantity_by_item_id(groups)
    max_qty   = groups.values.max
    item_ids  = groups.find_all { |item_id, qty| qty == max_qty }.to_h
    item_ids  = item_ids.keys
    items     = items_by_id_collection(item_ids).flatten.uniq
  end

  # TO DO - Test Me
  def revenue_by_item_id(hash)
    hash.each { |item_id, inv_items|
      hash[item_id] = inv_items.inject(0){ |sum, item| sum += revenue(item) }
    }; return hash
  end

  def best_item_for_merchant(merchant_id)
    invs = @invoices.find_all_by_merchant_id(merchant_id)
    inv_items = invs.map { |inv| invoice_items_of_successful_transactions(inv.id)}
    inv_items = inv_items.flatten.compact
    groups    = inv_items.group_by { |item| item.item_id  }
    groups    = revenue_by_item_id(groups)
    max_qty   = groups.values.max
    item_ids  = groups.find_all { |item_id, qty| qty == max_qty }.to_h
    item_ids  = item_ids.keys
    item      = items_by_id_collection(item_ids).flatten.first
  end

end
