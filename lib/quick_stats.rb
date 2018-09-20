require 'pry'


# How do you test a module in another file ?

module QuickStats
  def merchant_stats
    puts "     FIND ME  467"
    puts "all merchants: "    + @merchants.all.count.to_s
    puts "                -" + (475-467).to_s
    print_merchants_with_only_one_status
    print_merchants_with_only_one_result
    print_merchants_with_sales
    print_invoice_transactions
    print_invoices_with_failed_transactions
    print_missing_vs_failed
  end


# ---- Only One Status -------------------------------------------
  def print_merchants_with_only_one_status
    pending  = merchants_with_only_invoice(:pending).count.to_s
    shipped  = merchants_with_only_invoice(:shipped).count.to_s
    returned = merchants_with_only_invoice(:returned).count.to_s
    puts "only pending:      " + pending
    puts "only shipped:      " + shipped
    puts "only returned:     " + returned
  end

  def merchants_with_only_invoice(status)
    groups = invoice_statuses_by_merchants
    only = groups.find_all { |merch_id, stats|
      collection_all_same_status?(stats, status)
    }.to_h.keys
  end

  def invoice_statuses_by_merchants
    groups = invoices_grouped_by_merchant
    groups.each { |merch_id, invoices|
      groups[merch_id] = invoice_statuses_from_collection(invoices)
    }; return groups
  end

  def collection_all_same_status?(collection, status)
    collection.all?{ |stat| stat == status }
  end

  def invoice_statuses_from_collection(invoices)
    invoices.map {|inv| inv.status }
  end


  # ---- Only One Result -------------------------------------------

  def print_merchants_with_only_one_result
    success  = merchants_with_only_transaction(:success).count.to_s
    failed   = merchants_with_only_transaction(:failed).count.to_s
    puts "only success:        " + success
    puts "only failed:         " + failed
  end

  def merchants_with_only_transaction(result)
    groups = transactions_results_by_merchant
    only = groups.find_all { |inv_id, res|
      res = res.flatten
      collection_all_same_result?(res, result)
    }.to_h.keys
  end

  def transactions_results_by_merchant
    groups = transactions_by_merchant
    groups.each { |merch_id, trans|
      groups[merch_id] = trans.map { |t| t.result }
    }; return groups
  end

  def transactions_by_merchant
    groups = all_transactions_by_invoice_id               # inv_id   => [results]
    invoices = invoices_by_id_collection(groups.keys)     # merch_id => [invoices]
    sets = FinderClass.group_by(invoices, :merchant_id)
    sets.each { |merch_id, invoices|
      sets[merch_id] = invoices.map { |inv| groups[inv.id] }.flatten
     };return sets   # merch_id => [transactions]
  end

  def transaction_results_by_invoices
    groups = all_transactions_by_invoice_id
    groups.each { |inv_id, trans|
      groups[inv_id] = transaction_results_from_collection(trans)
    }; return groups
  end

  def collection_all_same_result?(collection, result)
    collection.all?{ |res| res == result }
  end

  def transaction_results_from_collection(transactions)
    transactions.map {|trans| trans.result}
  end


  # ---- All Merchants have -------------------------------------------

  def merchants_with_invoices
    groups    = invoices_grouped_by_merchant
    merch_ids = groups.keys
  end


  def merchants_with_transactions
    groups = transactions_by_merchant
    merch_ids = groups.keys
  end

  def print_merchants_with_sales
    invoices    = merchants_with_invoices.count.to_s
    tranactions = merchants_with_transactions.count.to_s
    puts "with invoices:             " + invoices
    puts "with transactions:         " + tranactions
  end


  # ---- Missing -------------------------------------------

  def print_invoice_transactions
    without = invoices_have_transactions(false)
    with    = invoices_have_transactions(true)
    merchants_without = collection_by_merchant_id(without).keys.count.to_s
    merchants_with    = collection_by_merchant_id(with).keys.count.to_s
    without = without.count.to_s
    with    = with.count.to_s
    puts "all invoices:              " + @invoices.all.count.to_s
    puts "Invoices without Trans:    " + without
    puts "   those merchants:      "   + merchants_without
    puts "Invoices with    Trans:    " + with
    puts "   those merchants:      "   + merchants_with
  end

  def invoices_have_transactions(bool)
    inv_ids   = all_transactions_by_invoice_id.keys
    other_ids = @invoices.all.find_all { |inv| inv_ids.include?(inv.id) == bool }
  end


  # ---- Invoices with Failed T -----------------------------

  def print_invoices_with_failed_transactions
    all = invoices_with_all_failed_transactions.count.to_s
    any = invoices_with_any_failed_transactions.count.to_s
    all_merch = merchants_with_all_failed_transactions.count.to_s
    any_merch = merchants_with_any_failed_transactions.count.to_s
    puts "invoices with all failed t " + all
    puts "   those merchants:      "   + all_merch
    puts "invoices with any failed t " + any
    puts "   those merchants:      "   + any_merch

  end

  def invoices_with_all_failed_transactions
    results = transaction_results_by_invoices
    inv_ids = results.find_all { |inv_id, results|
      results.all?{ |res| res == :failed }
    }.to_h.keys.uniq
  end

  def invoices_with_any_failed_transactions
    results = transaction_results_by_invoices
    inv_ids = results.find_all { |inv_id, results|
      results.any?{ |res| res == :failed }
    }.to_h.keys.uniq
  end

  def merchants_with_all_failed_transactions
    inv_ids   = invoices_with_all_failed_transactions
    invs      = inv_ids.map { |id| @invoices.find_by_id(id) }
    merch_ids = collection_by_merchant_id(invs).keys
  end

  def merchants_with_any_failed_transactions
    inv_ids   = invoices_with_any_failed_transactions
    invs      = inv_ids.map { |id| @invoices.find_by_id(id) }
    merch_ids = collection_by_merchant_id(invs).keys
  end



  # ---- Missing vs failed -------------------------------------------

  def print_missing_vs_failed
    both    = failed_and_missing.count.to_s
    either  = failed_or_missing.count.to_s
    puts "failed and missing:         " + both
    puts "failed or missing:          " + either
    puts "  BINGO failed or missing!  "
  end

  def invoice_ids_without_trans
    without = invoices_have_transactions(false)
    without = without.map { |inv| inv.id }
  end

  def merchants_without_transactions
    invs = invoices_have_transactions(false)
    collection_by_merchant_id(invs).keys
  end

  def failed_and_missing
    failed  = merchants_with_all_failed_transactions
    missing = merchants_without_transactions
    combo   = [failed, missing].flatten.uniq
    both    = combo.find_all { |id|
      failed.include?(id) && missing.include?(id)
     }
  end

  def failed_or_missing
    failed  = merchants_with_all_failed_transactions
    missing = merchants_without_transactions
    combo   = [failed, missing].flatten.uniq
  end

end
