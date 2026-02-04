public with sharing class WorkOrderInvoiceController {
    public class FilterOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public FilterOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkOrder__c> getWorkOrders() {
        return [
            SELECT Id, Name, Visit__c, Visit__r.Name, CreatedDate
            FROM WorkOrder__c
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(Id createdById, Id accountId) {
        List<String> whereClauses = new List<String>();
        if (createdById != null) {
            whereClauses.add('CreatedById = :createdById');
        }
        if (accountId != null) {
            whereClauses.add('Work_Order__r.Visit__r.Account__c = :accountId');
        }

        String soql =
            'SELECT Id, Name, CreatedDate, CreatedById, CreatedBy.Name,' +
            ' Invoice_Net_Total__c, Invoice_Status__c,' +
            ' Work_Order__c, Work_Order__r.Visit__c,' +
            ' Work_Order__r.Visit__r.Account__c,' +
            ' Work_Order__r.Visit__r.Account__r.Name' +
            ' FROM Invoice__c';

        if (!whereClauses.isEmpty()) {
            soql += ' WHERE ' + String.join(whereClauses, ' AND ');
        }
        soql += ' ORDER BY CreatedDate DESC';

        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<FilterOption> getInvoiceCreatedByOptions() {
        List<FilterOption> options = new List<FilterOption>();
        for (AggregateResult result : [
            SELECT CreatedById cbId, CreatedBy.Name cbName
            FROM Invoice__c
            GROUP BY CreatedById, CreatedBy.Name
            ORDER BY CreatedBy.Name
        ]) {
            String label = (String)result.get('cbName');
            String value = (String)result.get('cbId');
            if (label != null && value != null) {
                options.add(new FilterOption(label, value));
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<FilterOption> getInvoiceAccountOptions() {
        List<FilterOption> options = new List<FilterOption>();
        for (AggregateResult result : [
            SELECT Work_Order__r.Visit__r.Account__c accId,
                Work_Order__r.Visit__r.Account__r.Name accName
            FROM Invoice__c
            WHERE Work_Order__r.Visit__r.Account__c != null
            GROUP BY Work_Order__r.Visit__r.Account__c, Work_Order__r.Visit__r.Account__r.Name
            ORDER BY Work_Order__r.Visit__r.Account__r.Name
        ]) {
            String label = (String)result.get('accName');
            String value = (String)result.get('accId');
            if (label != null && value != null) {
                options.add(new FilterOption(label, value));
            }
        }
        return options;
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

    @AuraEnabled
    public static void updateInvoiceStatus(Id invoiceId, String newStatus) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice Id is required.');
        }
        if (String.isBlank(newStatus)) {
            throw new AuraHandledException('New status is required.');
        }

        Invoice__c invoice = [
            SELECT Id, Invoice_Status__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            FOR UPDATE
        ];

        String currentStatus = invoice.Invoice_Status__c;
        if (currentStatus == null) {
            throw new AuraHandledException('Invoice status is not set.');
        }

        if (!isValidStatusTransition(currentStatus, newStatus)) {
            throw new AuraHandledException(
                'Invalid status transition from ' + currentStatus + ' to ' + newStatus + '.'
            );
        }

        invoice.Invoice_Status__c = newStatus;
        update invoice;
    }

    private static Boolean isValidStatusTransition(String currentStatus, String newStatus) {
        if (currentStatus == 'Draft') {
            return newStatus == 'Issued' || newStatus == 'Void';
        }
        if (currentStatus == 'Issued') {
            return newStatus == 'Paid' || newStatus == 'Void';
        }
        if (currentStatus == 'Paid') {
            return newStatus == 'Void';
        }
        return false;
    }
}
