require 'pry'

require_relative 'finderclass'

class SalesAnalyst

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

  # --- General Methods ---

  # TO DO - Test the method part
  def sum(values, method = nil)
    values.inject(0) { |total, val|
      val = val.send(method) if method
      total += val
     }
   end

  def average(values, ct = values.count)
    sum     = sum(values)
    ct      = ct.to_f
    average = (sum / ct)
  end   # returns an unrounded float

  def percentage(fraction, all)
    (fraction / all.to_f ) * 100
  end

  def standard_deviation(values, mean) # Explicit steps
    floats      = values.map     { |val| val.to_f   }
    difference  = floats.map     { |val| val - mean }
    values      = difference.map { |val| val ** 2   }
    sample_ct   = (values.count - 1)
    div         = average(values, sample_ct)
    sqrt        = Math.sqrt(div)
    return sqrt.round(2)
  end   # returns float rounded to 2 places

  def standard_dev_measure(values, above_or_below, std = nil)
    mean = average(values)
    std == nil ? std = standard_deviation(values, mean) : std
    outside_this = mean + (std * above_or_below)
  end # returns a float

  def find_exceptional(collection, values, stds, method)
    case collection
    when Hash;  exceptional_from_hash(collection, values, stds, method)
    when Array; exceptional_from_array(collection, values, stds, method)
    end
  end

  def exceptional_from_hash(collection, values, stds, method)
    stds > 0 ? operator = :> : operator = :<
    std_limit = standard_dev_measure(values, stds)
    list = collection.find_all {|key, value|
      value.send(method).send(operator, std_limit)
    }.to_h
    return list
  end

  def exceptional_from_array(collection, values, stds, method)
    stds > 0 ? operator = :> : operator = :<
    std_limit = standard_dev_measure(values, stds)
    list = collection.find_all {|object|
      object.send(method).send(operator, std_limit)
    }
    return list
  end


  # --- Item Repo Analysis Methods ---

  def merchant_stores
    groups = FinderClass.group_by(@items.all, :merchant_id)
  end

  def merchant_store_item_counts(groups)
    vals = FinderClass.make_array(groups.values, :count)
  end

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
    values      = merchant_store_item_counts(groups)
    all_above = find_exceptional(groups, values, 1, :count)
    merch_ids = all_above.keys
    list = FinderClass.match_by_data(@merchants.all, merch_ids, :id)
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

  def invoices_grouped_by_merchant
    groups = FinderClass.group_by(@invoices.all, :merchant_id)
  end

  def invoice_counts_per_merchant
    groups = invoices_grouped_by_merchant
    counts = groups.map { |id, invoices| invoices.count.to_f }
  end

  def average_invoices_per_merchant
    counts = invoice_counts_per_merchant
    mean = average(counts).round(2)
  end

  def average_invoices_per_merchant_standard_deviation
    counts = invoice_counts_per_merchant
    mean = average_invoices_per_merchant
    std = standard_deviation(counts, mean).round(2)
  end

  def top_merchants_by_invoice_count  # two standard deviations above the mean
    groups = invoices_grouped_by_merchant
    counts = invoice_counts_per_merchant
    top = find_exceptional(groups, counts, 2, :count)
    merch_ids = top.keys
    top_merchants = FinderClass.match_by_data(@merchants.all, merch_ids, :id )

  end

  def bottom_merchants_by_invoice_count  # two standard deviations below the mean
    groups = invoices_grouped_by_merchant
    counts = invoice_counts_per_merchant
    worst = find_exceptional(groups, counts, -2, :count)
    merch_ids = worst.keys
    bottom_merchants = FinderClass.match_by_data(@merchants.all, merch_ids, :id )
  end

  def top_days_by_invoice_count
    groups = @invoices.all.group_by { |invoice| invoice.created_at.wday}
    values = FinderClass.make_array(groups.values, :count)
    top = find_exceptional(groups, values, 1, :count)
    top_as_word = top.keys.map { |day| FinderClass.day_of_week(day) }
  end

  def invoice_status(status)
    all = @invoices.all.count.to_f
    found = @invoices.find_all_by_status(status).count
    percent = percentage(found, all).round(2)
  end


  # --- Transaction Repo Analysis Methods ---

  def invoice_paid_in_full?(invoice_id) # Paid in full if t/f
    sale = @transactions.find_all_by_invoice_id(invoice_id)
    sale.any? { |trans| trans.result == :success }
  end

  def invoice_items_of_successful_transactions(invoice_id)
    sold = invoice_paid_in_full?(invoice_id)
    items_by_invoice = @invoice_items.find_all_by_invoice_id(invoice_id) if sold
  end

  def invoice_total(invoice_id)
    items_by_invoice = invoice_items_of_successful_transactions(invoice_id)
    if items_by_invoice
      sum = items_by_invoice.inject(0) { |sum, item|
        cost = item.quantity * item.unit_price
        sum += cost
      }
      return sum
    end
  end


  # --- Merchant Revenue Analysis Methods ---

  def total_revenue_by_date(date)
    day_invoices = FinderClass.find_by_all_by_date(@invoices.all, :created_at, date)
    inv_ids      = FinderClass.make_array(day_invoices, :id).flatten
    inv_costs    = inv_ids.map{ |id| invoice_total(id) } #.compact!
    total        = sum(inv_costs)
  end


  def top_revenue_earners(x = 20)
    hash = @invoices.all.group_by {|inv| inv.merchant_id}
    hash.each { |id, invs|
      inv_ids = invs.map { |inv| inv.id }
      costs = inv_ids.map { |inv_id| invoice_total(inv_id) }
      hash[id] = costs.compact
    }
    hash.each { |id, costs| hash[id] = sum(costs)}
    top = hash.max_by(x) { |key, cost| cost}.to_h
    top_ids = top.keys
    list = top_ids.map { |id| @merchants.find_by_id(id)}
  end

  def merchants_with_pending_invoices
    # pending = @invoices.find_all_by_status(:pending)
    # inv_ids = pending.map { |inv| inv.id }
    # successful = inv_ids.find_all { |id| invoice_paid_in_full?(id) }
    # ids = successful.map {|id| .merchant_id }.uniq
    # merchants = ids.map { |id| @merchants.find_by_id(id) }
    pending = @invoices.all.find_all { |invoice|
      successful_and_pending?(invoice.id)
    }
    shops = pending.group_by{ |invoice| invoice.merchant_id }
    merch_ids = shops.keys
    merchants = merch_ids.map { |id| @merchants.find_by_id(id) }
  end

  def successful_and_pending?(invoice_id)
    success = invoice_paid_in_full?(invoice_id)
    invoice = @invoices.find_by_id(invoice_id)
    pending = invoice.status == :pending
    success && pending
  end

  def groups_of_merchant_items
    @items.all.group_by { |item| item.merchant_id }
  end

  def single_item_merchant_pairs
    groups = groups_of_merchant_items
    groups.each{ |id, items| groups[id] = items.count }
    ones = groups.find_all { |id, count| count == 1 }.to_h
  end

  def merchants_with_only_one_item
    # groups = groups_of_merchant_items
    # groups.each{ |id, items| groups[id] = items.count }
    # ones = groups.find_all { |id, count| count == 1 }.to_h
    # ids = ones.keys
    ids = single_item_merchant_pairs.keys
    merchs = ids.map { |id| @merchants.find_by_id(id) }
    binding.pry
    return merchs
  end

  def merchants_with_only_one_item_registered_in_month(word)
    month = FinderClass.month_from_word(word).to_i
    # months = @items.all.group_by { |item| item.updated_at.month }
    # month_items = months[month]
    # groups = month_items.group_by { |item| item.merchant_id }
    # groups.each { |id, m_items| groups[id] = m_items.count }
    # ones = groups.find_all { |id, count| count == 1 }.to_h
    # ids = ones.keys
    # merchants = ids.map { |id| @merchants.find_by_id(id) }
    # === Above works but is a different iterpretation of statement =====
    shops = merchants_with_only_one_item
    binding.pry
    groups = shops.group_by { |shop| shop.created_at.month }
    list = groups[month]
  end


  def revenue_by_merchant(merchant_id)
  end

  def most_sold_item_for_merchant(merchant_id)
    merch_invoices = @invoices.find_all_by_merchant_id(merchant_id)
    inv_ids = merch_invoices.map { |inv| inv.id }
    merch_items = inv_ids.map { |id| @invoice_items.find_all_by_invoice_id(id)}.flatten
    
  end

  def best_item_for_merchant(merchant_id)
  end


end
