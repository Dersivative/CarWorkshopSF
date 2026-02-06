public with sharing class WorkOrderInvoiceController {
    public class FilterOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public FilterOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class InvoiceLineDto {
        @AuraEnabled public String lineId;
        @AuraEnabled public String name;
        @AuraEnabled public String productOrServiceId;
        @AuraEnabled public String lineType;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal netTotal;
        @AuraEnabled public Decimal grossTotal;
        @AuraEnabled public Decimal taxRate;
        @AuraEnabled public String description;
    }

    public class InvoiceDetailDto {
        @AuraEnabled public String invoiceId;
        @AuraEnabled public String invoiceName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String clientName;
        @AuraEnabled public Decimal totalNet;
        @AuraEnabled public Decimal totalGross;
        @AuraEnabled public String status;
        @AuraEnabled public List<InvoiceLineDto> lines;
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkOrder__c> getWorkOrders() {
        return [
            SELECT Id, Name, Visit__c, Visit__r.Name, CreatedDate,
                Assigned_Employee__c, Assigned_Employee__r.Name
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
    public static InvoiceDetailDto getInvoiceDetail(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice Id is required.');
        }

        Invoice__c invoice = [
            SELECT Id,
                Name,
                CreatedDate,
                CreatedBy.Name,
                Invoice_Net_Total__c,
                Invoice_Gross_Total__c,
                Invoice_Status__c,
                Work_Order__r.Visit__r.Account__r.Name
            FROM Invoice__c
            WHERE Id = :invoiceId
        ];

        List<Invoice_Line_Item__c> lineItems = [
            SELECT Id,
                Name,
                Line_Type__c,
                Quantity__c,
                Unit_Price__c,
                Net_Line_Total__c,
                Gross_Line_Total__c,
                Tax_Rate__c,
                Product__c,
                Product__r.Name,
                Product__r.Product_Description__c,
                Service__c,
                Service__r.Name,
                Service__r.Service_Description__c
            FROM Invoice_Line_Item__c
            WHERE Invoice__c = :invoiceId
            ORDER BY Name
        ];

        InvoiceDetailDto detail = new InvoiceDetailDto();
        detail.invoiceId = invoice.Id;
        detail.invoiceName = invoice.Name;
        detail.createdDate = invoice.CreatedDate;
        detail.createdByName = invoice.CreatedBy != null ? invoice.CreatedBy.Name : null;
        detail.clientName = invoice.Work_Order__r != null &&
            invoice.Work_Order__r.Visit__r != null &&
            invoice.Work_Order__r.Visit__r.Account__r != null
            ? invoice.Work_Order__r.Visit__r.Account__r.Name
            : null;
        detail.totalNet = invoice.Invoice_Net_Total__c;
        detail.totalGross = invoice.Invoice_Gross_Total__c;
        detail.status = invoice.Invoice_Status__c;
        detail.lines = new List<InvoiceLineDto>();

        for (Invoice_Line_Item__c lineItem : lineItems) {
            InvoiceLineDto lineDto = new InvoiceLineDto();
            lineDto.lineId = lineItem.Id;
            lineDto.lineType = lineItem.Line_Type__c;
            lineDto.quantity = lineItem.Quantity__c;
            lineDto.unitPrice = lineItem.Unit_Price__c;
            lineDto.netTotal = lineItem.Net_Line_Total__c;
            lineDto.grossTotal = lineItem.Gross_Line_Total__c;
            lineDto.taxRate = lineItem.Tax_Rate__c;
            if (lineItem.Product__r != null) {
                lineDto.productOrServiceId = lineItem.Product__c;
                lineDto.name = lineItem.Product__r.Name;
                lineDto.description = lineItem.Product__r.Product_Description__c;
            } else if (lineItem.Service__r != null) {
                lineDto.productOrServiceId = lineItem.Service__c;
                lineDto.name = lineItem.Service__r.Name;
                lineDto.description = lineItem.Service__r.Service_Description__c;
            } else {
                lineDto.name = lineItem.Name;
            }
            detail.lines.add(lineDto);
        }

        return detail;
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

    // If conversion fails with a validation error about Assigned Employee, ensure Work_Order__r.Assigned_Employee__c is set before creating an invoice (e.g. via a validation rule in the org).
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

        Map<Id, Decimal> productIdToQty = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : workOrderLineItems) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue;
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0;
            productIdToQty.put(
                line.Product__c,
                (productIdToQty.get(line.Product__c) != null ? productIdToQty.get(line.Product__c) : 0) + qty
            );
        }
        if (!productIdToQty.isEmpty()) {
            List<Product__c> toUpdate = new List<Product__c>();
            for (Product__c p : [
                SELECT Id, Quantity_Reserved__c, Quantity_On_Hand__c
                FROM Product__c
                WHERE Id IN :productIdToQty.keySet()
            ]) {
                Decimal qty = productIdToQty.get(p.Id);
                p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) - qty;
                if (p.Quantity_Reserved__c < 0) p.Quantity_Reserved__c = 0;
                p.Quantity_On_Hand__c = (p.Quantity_On_Hand__c != null ? p.Quantity_On_Hand__c : 0) - qty;
                if (p.Quantity_On_Hand__c < 0) p.Quantity_On_Hand__c = 0;
                toUpdate.add(p);
            }
            update toUpdate;
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

        if (newStatus == 'Void') {
            Map<Id, Decimal> productIdToQty = new Map<Id, Decimal>();
            for (AggregateResult ar : [
                SELECT Product__c pId, SUM(Quantity__c) totalQty
                FROM Invoice_Line_Item__c
                WHERE Invoice__c = :invoiceId
                    AND Line_Type__c = 'Product'
                    AND Product__c != null
                GROUP BY Product__c
            ]) {
                Id pId = (Id)ar.get('pId');
                Decimal totalQty = (Decimal)ar.get('totalQty');
                if (pId != null && totalQty != null) {
                    productIdToQty.put(pId, totalQty);
                }
            }
            if (!productIdToQty.isEmpty()) {
                List<Product__c> toUpdate = new List<Product__c>();
                for (Product__c p : [
                    SELECT Id, Quantity_On_Hand__c
                    FROM Product__c
                    WHERE Id IN :productIdToQty.keySet()
                ]) {
                    Decimal qty = productIdToQty.get(p.Id);
                    p.Quantity_On_Hand__c = (p.Quantity_On_Hand__c != null ? p.Quantity_On_Hand__c : 0) + qty;
                    toUpdate.add(p);
                }
                update toUpdate;
            }
        }
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
