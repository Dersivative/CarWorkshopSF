@IsTest
private class WorkOrderDetailControllerTest {
    @IsTest
    static void getWorkOrderDetailReturnsHeaderAndLines() {
        WorkOrder__c workOrder = createWorkOrderWithLines();

        Test.startTest();
        WorkOrderDetailController.WorkOrderDetailDto detail =
            WorkOrderDetailController.getWorkOrderDetail(workOrder.Id);
        Test.stopTest();

        System.assertEquals(workOrder.Id, detail.workOrderId);
        System.assertNotEquals(null, detail.workOrderName);
        System.assertNotEquals(null, detail.visitId);
        System.assertNotEquals(null, detail.vehicleId);
        System.assertEquals(2, detail.lineItems.size());
        System.assert(detail.grossTotal != null, 'Gross total should be calculated.');
    }

    @IsTest
    static void getWorkOrderDetailRequiresId() {
        try {
            WorkOrderDetailController.getWorkOrderDetail(null);
            System.assert(false, 'Expected AuraHandledException for missing Work Order Id.');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('Work Order Id is required.'),
                'Exception message should indicate missing Work Order Id.'
            );
        }
    }

    private static WorkOrder__c createWorkOrderWithLines() {
        String stamp = String.valueOf(DateTime.now().getTime());

        Account account = new Account(Name = 'Detail Test Account ' + stamp);
        insert account;

        Vehicle__c vehicle = new Vehicle__c(
            Name = 'VIN-' + stamp,
            Account__c = account.Id,
            Plate__c = 'DET-' + stamp.right(6)
        );
        insert vehicle;

        Visit__c visit = new Visit__c(
            Account__c = account.Id,
            Vehicle__c = vehicle.Id,
            Odometer_km__c = 12345
        );
        insert visit;

        WorkOrder__c workOrder = new WorkOrder__c(Visit__c = visit.Id);
        insert workOrder;

        Product__c product = new Product__c(
            Price__c = 25,
            Quantity_On_Hand__c = 5,
            Product_Description__c = 'Detail Product ' + stamp
        );
        insert product;

        Service__c service = new Service__c(
            Default_Labour_Hours__c = 1,
            Hourly_Rate__c = 100,
            Tax_Rate__c = 0,
            Service_Description__c = 'Detail Service ' + stamp
        );
        insert service;

        Work_Order_Line_Item__c productLine = new Work_Order_Line_Item__c(
            Work_Order__c = workOrder.Id,
            Line_Type__c = 'Product',
            Product__c = product.Id,
            Quantity__c = 2,
            Unit_Price__c = 25,
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