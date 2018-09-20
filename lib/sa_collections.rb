require 'pry'

require_relative 'finderclass'

module SACollections

  # --- Item Repo Analysis Methods ---

  # items by merchant
  def merchant_stores
    groups = FinderClass.group_by(@items.all, :merchant_id)
  end

  def merchant_store_item_counts(groups)
    vals = FinderClass.make_array(groups.values, :count)
  end


  # --- Invoice Repo Analysis Methods ---

  def invoices_grouped_by_merchant
    groups = FinderClass.group_by(@invoices.all, :merchant_id)
  end


  # --- Transaction Repo Analysis Methods ---

  # TO DO - test me, but is tested other places
  def merchants_by_id_collection(collection)
    FinderClass.match_by_data(@merchants.all, collection, :id)
  end

  # TO DO - test me, but is tested other places
  def invoices_by_id_collection(collection)
    FinderClass.match_by_data(@invoices.all, collection, :id)
  end

  # TO DO - test me, but is tested other places
  def invoice_items_by_id_collection(collection)
    FinderClass.match_by_data(@invoice_items.all, collection, :id)
  end

  # TO DO - test me, but is tested other places
  def items_by_id_collection(collection)
    FinderClass.match_by_data(@items.all, collection, :id)
  end

  #  TO DO - test me but already tested other places
  def invoice_items_grouped_by_item(invoice_items)
    FinderClass.group_by(invoice_items, :item_id)
  end


  def all_transactions_by_invoice_id
    FinderClass.group_by(@transactions.all, :invoice_id)
  end

  def collection_by_merchant_id(collection)
    FinderClass.group_by(collection, :merchant_id)
  end


end
