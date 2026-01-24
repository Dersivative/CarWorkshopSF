public with sharing class WorkOrderLineItemConverter {
    // Converts Work Order line items into Invoice line items.
    public static List<Invoice_Line_Item__c> convert(
        List<Work_Order_Line_Item__c> workOrderLineItems,
        Id invoiceId
    ) {
        if (invoiceId == null) {
            throw new IllegalArgumentException('Invoice Id is required for conversion.');
        }

        if (workOrderLineItems == null || workOrderLineItems.isEmpty()) {
            return new List<Invoice_Line_Item__c>();
        }

        List<Invoice_Line_Item__c> invoiceLineItems = new List<Invoice_Line_Item__c>();
        for (Work_Order_Line_Item__c sourceLine : workOrderLineItems) {
            invoiceLineItems.add(createInvoiceLineItem(sourceLine, invoiceId));
        }

        return invoiceLineItems;
    }

    public static List<Invoice_Line_Item__c> convertWithMapping(
        List<Work_Order_Line_Item__c> workOrderLineItems,
        Map<Id, Id> workOrderToInvoiceId
    ) {
        if (workOrderToInvoiceId == null || workOrderToInvoiceId.isEmpty()) {
            throw new IllegalArgumentException('Work order to invoice mapping is required for conversion.');
        }

        if (workOrderLineItems == null || workOrderLineItems.isEmpty()) {
            return new List<Invoice_Line_Item__c>();
        }

        List<Invoice_Line_Item__c> invoiceLineItems = new List<Invoice_Line_Item__c>();
        for (Work_Order_Line_Item__c sourceLine : workOrderLineItems) {
            Id invoiceId = workOrderToInvoiceId.get(sourceLine.Work_Order__c);
            if (invoiceId == null) {
                throw new IllegalArgumentException('Missing invoice mapping for Work Order ' + sourceLine.Work_Order__c);
            }

            invoiceLineItems.add(createInvoiceLineItem(sourceLine, invoiceId));
        }

        return invoiceLineItems;
    }

    private static Invoice_Line_Item__c createInvoiceLineItem(
        Work_Order_Line_Item__c sourceLine,
        Id invoiceId
    ) {
        if (sourceLine == null) {
            throw new IllegalArgumentException('Source Work Order line item cannot be null.');
        }

        Invoice_Line_Item__c invoiceLine = new Invoice_Line_Item__c();
        invoiceLine.Invoice__c = invoiceId;
        invoiceLine.Line_Type__c = sourceLine.Line_Type__c;
        invoiceLine.Product__c = sourceLine.Product__c;
        invoiceLine.Service__c = sourceLine.Service__c;
        invoiceLine.Quantity__c = sourceLine.Quantity__c;
        invoiceLine.Unit_Price__c = sourceLine.Unit_Price__c;
        invoiceLine.Tax_Rate__c = sourceLine.Tax_Rate__c;
        invoiceLine.Net_Line_Total__c = sourceLine.Net_Line_Total__c;
        invoiceLine.Gross_Line_Total__c = sourceLine.Gross_Line_Total__c;

        return invoiceLine;
    }
}
