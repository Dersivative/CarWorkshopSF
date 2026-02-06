@IsTest
private class WorkOrderInvoiceControllerTest {
    @IsTest
    static void createInvoiceForWorkOrderCreatesInvoiceAndLines() {
        WorkOrder__c workOrder = createWorkOrderWithLines();

        Test.startTest();
        Id invoiceId = WorkOrderInvoiceController.createInvoiceForWorkOrder(workOrder.Id);
        Test.stopTest();

        Invoice__c invoice = [
            SELECT Id, Work_Order__c, Invoice_Status__c, Invoice_Net_Total__c, Invoice_Gross_Total__c
            FROM Invoice__c
            WHERE Id = :invoiceId
        ];

        System.assertEquals(workOrder.Id, invoice.Work_Order__c, 'Invoice should reference Work Order.');
        System.assertEquals('Draft', invoice.Invoice_Status__c, 'Invoice status should be Draft.');

        List<Invoice_Line_Item__c> invoiceLines = [
            SELECT Id
            FROM Invoice_Line_Item__c
            WHERE Invoice__c = :invoiceId
        ];
        System.assertEquals(2, invoiceLines.size(), 'Invoice should have copied line items.');

        List<Work_Order_Line_Item__c> workOrderLines = [
            SELECT Net_Line_Total__c, Gross_Line_Total__c
            FROM Work_Order_Line_Item__c
            WHERE Work_Order__c = :workOrder.Id
        ];

        Decimal totalNet = 0;
        Decimal totalGross = 0;
        for (Work_Order_Line_Item__c line : workOrderLines) {
            if (line.Net_Line_Total__c != null) {
                totalNet += line.Net_Line_Total__c;
            }
            if (line.Gross_Line_Total__c != null) {
                totalGross += line.Gross_Line_Total__c;
            }
        }

        System.assertEquals(totalNet, invoice.Invoice_Net_Total__c, 'Invoice net total should match lines.');
        System.assertEquals(totalGross, invoice.Invoice_Gross_Total__c, 'Invoice gross total should match lines.');
    }

    @IsTest
    static void getWorkOrdersReturnsWorkOrders() {
        WorkOrder__c workOrder = createWorkOrderWithLines();

        List<WorkOrder__c> results = WorkOrderInvoiceController.getWorkOrders();

        System.assert(!results.isEmpty(), 'Expected work orders to be returned.');
        Boolean containsWorkOrder = false;
        for (WorkOrder__c result : results) {
            if (result.Id == workOrder.Id) {
                containsWorkOrder = true;
                break;
            }
        }
        System.assert(containsWorkOrder, 'Work order should be present in results.');
    }

    @IsTest
    static void createInvoiceForWorkOrderRequiresId() {
        try {
            WorkOrderInvoiceController.createInvoiceForWorkOrder(null);
            System.assert(false, 'Expected AuraHandledException for null Work Order Id.');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage() != null && ex.getMessage().contains('Work Order Id'),
                'Exception message should indicate missing Work Order Id.'
            );
        }
    }

    @IsTest
    static void createInvoiceForWorkOrderDecrementsProductReservedAndOnHand() {
        WorkOrder__c workOrder = createWorkOrderWithLines();
        Id productId = [SELECT Product__c FROM Work_Order_Line_Item__c WHERE Line_Type__c = 'Product' AND Work_Order__c = :workOrder.Id LIMIT 1].Product__c;
        Product__c productBefore = [SELECT Quantity_Reserved__c, Quantity_On_Hand__c FROM Product__c WHERE Id = :productId];

        Test.startTest();
        WorkOrderInvoiceController.createInvoiceForWorkOrder(workOrder.Id);
        Test.stopTest();

        Product__c productAfter = [SELECT Quantity_Reserved__c, Quantity_On_Hand__c FROM Product__c WHERE Id = :productId];
        Decimal reservedBefore = productBefore.Quantity_Reserved__c != null ? productBefore.Quantity_Reserved__c : 0;
        Decimal onHandBefore = productBefore.Quantity_On_Hand__c != null ? productBefore.Quantity_On_Hand__c : 0;
        System.assertEquals(reservedBefore - 2, productAfter.Quantity_Reserved__c, 'Reserved should decrease by line quantity.');
        System.assertEquals(onHandBefore - 2, productAfter.Quantity_On_Hand__c, 'On hand should decrease by line quantity.');
    }

    @IsTest
    static void updateInvoiceStatusVoidRestoresOnHand() {
        WorkOrder__c workOrder = createWorkOrderWithLines();
        Id invoiceId = WorkOrderInvoiceController.createInvoiceForWorkOrder(workOrder.Id);
        Id productId = [SELECT Product__c FROM Invoice_Line_Item__c WHERE Invoice__c = :invoiceId AND Line_Type__c = 'Product' LIMIT 1].Product__c;
        Decimal onHandAfterCreate = [SELECT Quantity_On_Hand__c FROM Product__c WHERE Id = :productId].Quantity_On_Hand__c;

        Test.startTest();
        WorkOrderInvoiceController.updateInvoiceStatus(invoiceId, 'Void');
        Test.stopTest();

        Decimal onHandAfterVoid = [SELECT Quantity_On_Hand__c FROM Product__c WHERE Id = :productId].Quantity_On_Hand__c;
        System.assertEquals(onHandAfterCreate + 2, onHandAfterVoid, 'Voiding invoice should restore product quantity on hand.');
    }

    private static WorkOrder__c createWorkOrderWithLines() {
        Account account = new Account(Name = 'Test Account');
        insert account;

        Vehicle__c vehicle = new Vehicle__c(
            Name = '12345678901234567',
            Account__c = account.Id,
            Plate__c = 'XYZ-123'
        );
        insert vehicle;

        Visit__c visit = new Visit__c(
            Account__c = account.Id,
            Vehicle__c = vehicle.Id
        );
        insert visit;

        WorkOrder__c workOrder = new WorkOrder__c(Visit__c = visit.Id);
        insert workOrder;

        Product__c product = new Product__c(
            Price__c = 10,
            Quantity_On_Hand__c = 5,
            Tax_Rate__c = 0,
            Product_Description__c = 'Oil Filter ' + String.valueOf(DateTime.now().getTime())
        );
        insert product;

        Service__c service = new Service__c(
            Default_Labour_Hours__c = 1,
            Hourly_Rate__c = 100,
            Tax_Rate__c = 0,
            Service_Description__c = 'Oil Change ' + String.valueOf(DateTime.now().getTime())
        );
        insert service;

        Work_Order_Line_Item__c productLine = new Work_Order_Line_Item__c(
            Work_Order__c = workOrder.Id,
            Line_Type__c = 'Product',
            Product__c = product.Id,
            Quantity__c = 2,
            Unit_Price__c = 10,
            Tax_Rate__c = 0
        );

        Work_Order_Line_Item__c serviceLine = new Work_Order_Line_Item__c(
            Work_Order__c = workOrder.Id,
            Line_Type__c = 'Service',
            Service__c = service.Id,
            Quantity__c = 1,
            Unit_Price__c = 100,
            Tax_Rate__c = 0
        );
       

        insert new List<Work_Order_Line_Item__c>{ productLine, serviceLine };

        return workOrder;
    }
}
