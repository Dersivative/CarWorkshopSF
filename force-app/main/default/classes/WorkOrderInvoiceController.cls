public with sharing class WorkOrderInvoiceController {
    @AuraEnabled(cacheable=true)
    public static List<WorkOrder__c> getWorkOrders() {
        return [
            SELECT Id, Name, Visit__c, Visit__r.Name, CreatedDate
            FROM WorkOrder__c
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static Id createInvoiceForWorkOrder(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order Id is required.');
        }

        List<Work_Order_Line_Item__c> workOrderLineItems = [
            SELECT Id,
                Work_Order__c,
                Line_Type__c,
                Product__c,
                Service__c,
                Quantity__c,
                Unit_Price__c,
                Tax_Rate__c,
                Net_Line_Total__c,
                Gross_Line_Total__c
            FROM Work_Order_Line_Item__c
            WHERE Work_Order__c = :workOrderId
        ];

        Invoice__c invoice = new Invoice__c(
            Work_Order__c = workOrderId,
            Invoice_Status__c = 'Draft'
        );
        insert invoice;

        if (!workOrderLineItems.isEmpty()) {
            List<Invoice_Line_Item__c> invoiceLineItems = WorkOrderLineItemConverter.convert(
                workOrderLineItems,
                invoice.Id
            );
            insert invoiceLineItems;
        }

        return invoice.Id;
    }
}
