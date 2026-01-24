trigger WorkOrderLineItemTypeEnforcer on Work_Order_Line_Item__c (before insert, before update) {
	for (Work_Order_Line_Item__c lineItem : Trigger.new) {
		if (String.isBlank(lineItem.Line_Type__c)) {
			continue;
		}
		Boolean hasProduct = lineItem.Product__c != null;
		Boolean hasService = lineItem.Service__c != null;

		if (lineItem.Line_Type__c == 'Product') {
			if (!hasProduct) {
				lineItem.Product__c.addError('Product line must reference a product.');
			}
			if (hasService) {
				lineItem.Service__c.addError('Product line cannot reference a service.');
			}
		} else if (lineItem.Line_Type__c == 'Service') {
			if (!hasService) {
				lineItem.Service__c.addError('Service line must reference a service.');
			}
			if (hasProduct) {
				lineItem.Product__c.addError('Service line cannot reference a product.');
			}
		}
	}
}