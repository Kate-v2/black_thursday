require 'pry'


module QuickStats
  def merchant_stats
    puts "all merchants:      "    + @merchants.all.count.to_s
    merchants_by_invoice_status
    merchants_by_transaction_result
    merchants_with_success_or_pending
    merchants_with_failure_or_pending
    merchants_with_success_and_pending
    merchants_with_failure_and_pending
    merchants_with_transactions
    merchants_with_invoices
    invoices_with_all_failed_transactions
    invoices_with_all_success_transactions
    invoices_without_transactions
  end

  def invoices_without_transactions
    inv_ids = @transactions.all.group_by { |t| t.invoice_id}.keys
    other_ids = @invoices.all.find_all { |inv| inv_ids.include?(inv.id) == false  }
    merch_ids = other_ids.group_by { |inv| inv.merchant_id }.keys
    ct = merch_ids.count
    puts "Invoices without Trans:    " + ct.to_s
  end

  def invoices_with_all_success_transactions
    groups = @transactions.all.group_by { |t| t.invoice_id}
    groups.each { |inv_id, trans| groups[inv_id] = trans.map { |t| t.result } }
    failed  = groups.find_all { |inv_id, results|
      results.all?{ |r| r == :success } }.to_h
    inv_ids = failed.keys
    invs = invoices_by_id_collection(inv_ids)
    pairs = invs.group_by { |inv| inv.merchant_id }
    merch_ids = pairs.keys
    ct = merch_ids.count
    puts "invoices all success t:    " + ct.to_s
    puts "interesting that this is 4 above target and 4 below all"
  end



  def invoices_with_all_failed_transactions
    groups = @transactions.all.group_by { |t| t.invoice_id}
    groups.each { |inv_id, trans| groups[inv_id] = trans.map { |t| t.result } }
    failed  = groups.find_all { |inv_id, results|
      results.all?{ |r| r == :failed } }.to_h
    inv_ids = failed.keys
    invs = invoices_by_id_collection(inv_ids)
    pairs = invs.group_by { |inv| inv.merchant_id }
    merch_ids = pairs.keys
    ct = merch_ids.count
    puts "invoices all failed t:     " + ct.to_s
  end


  def merchants_with_invoices
    groups = @invoices.all.group_by { |inv| inv.merchant_id }
    ct = groups.keys.count
    puts "with invoices:             " + ct.to_s
  end


  def merchants_with_transactions
    groups = @transactions.all.group_by { |t| t.invoice_id}
    inv_ids = groups.keys
    invs = invoices_by_id_collection(inv_ids)
    pairs = invs.group_by{ |inv| inv.merchant_id}
    ct = pairs.keys.count
    puts "with transactions:         " + ct.to_s
  end

  def merchants_with_success_or_pending
    success_ids = find_transactions_by_status(:success)
    pending_ids = find_invoices_by_status(:pending)
    all = success_ids + pending_ids
    ct = all.uniq.count
    puts "pending or success:        " + ct.to_s
  end

  def merchants_with_failure_or_pending
    success_ids = find_transactions_by_status(:failed)
    pending_ids = find_invoices_by_status(:pending)
    all = success_ids + pending_ids
    ct = all.uniq.count
    puts "pending or failed:         " + ct.to_s
  end

  def merchants_with_success_and_pending
    success_ids = find_transactions_by_status(:success)
    pending_ids = find_invoices_by_status(:pending)
    combo = success_ids + pending_ids
    all   = combo.find_all { |id|
      success_ids.include?(id) && pending_ids.include?(id)  }
    ct = all.uniq.count
    puts "pending and success:       " + ct.to_s
  end

  def merchants_with_failure_and_pending
    success_ids = find_transactions_by_status(:failed)
    pending_ids = find_invoices_by_status(:pending)
    combo = success_ids + pending_ids
    all   = combo.find_all { |id|
      success_ids.include?(id) && pending_ids.include?(id)  }
    ct = all.uniq.count
    puts "pending and failed:        " + ct.to_s
  end


  def merchants_by_transaction_result
    # puts "all transactions: " + @transactions.all.count.to_s
    success = find_transactions_by_status(:success).count
    failed  = find_transactions_by_status(:failed).count
    puts "all by t success:          "  + success.to_s
    puts "all by t failed:           "   + failed.to_s
  end

  # Name BAD - returns merchant ids
  def find_transactions_by_status(result)
    by_stat = @transactions.all.find_all { |t| t.result == result }
    inv_ids = by_stat.group_by { |t| t.invoice_id }
    ids     = inv_ids.keys
    invs    = ids.map { |id| @invoices.find_by_id(id) }.flatten
    pairs   = invs.group_by { |inv| inv.merchant_id }
    merch_ids = pairs.keys
  end

  def merchants_by_invoice_status
    pending  = find_invoices_by_status(:pending).count
    shipped  = find_invoices_by_status(:shipped).count
    returned = find_invoices_by_status(:returned).count
    puts "all by pending:            "  + pending.to_s
    puts "all by shipped:            "   + shipped.to_s
    puts "all by returned:           "  + returned.to_s
  end

  # Name BAD - returns merchant ids
  def find_invoices_by_status(status)
    invoices = invoices_grouped_by_merchant
    pairs = invoices.find_all { |merch_id, invs|
      invs.any?{ |inv| inv.status == status }
    }.to_h
    merch_ids = pairs.keys
  end

  def successful_and_pending?(invoice_id)
    success = invoice_paid_in_full?(invoice_id)
    invoice = @invoices.find_by_id(invoice_id)
    pending = invoice.status == :pending
    success && pending
  end




end
