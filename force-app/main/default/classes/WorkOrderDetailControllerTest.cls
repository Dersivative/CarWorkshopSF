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
                ex.getMessage() != null && ex.getMessage().contains('Work Order Id'),
                'Exception message should indicate missing Work Order Id.'
            );
        }
    }

    @IsTest
    static void getServiceCatalogReturnsList() {
        Service__c svc = new Service__c(
            Service_Description__c = 'Test Svc',
            Hourly_Rate__c = 50,
            Tax_Rate__c = 0.1,
            Default_Labour_Hours__c = 2
        );
        insert svc;

        Test.startTest();
        List<WorkOrderDetailController.ServiceCatalogDto> result =
            WorkOrderDetailController.getServiceCatalog();
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Expected at least one service.');
        Boolean found = false;
        for (WorkOrderDetailController.ServiceCatalogDto dto : result) {
            if (dto.Id == svc.Id) {
                found = true;
                System.assertEquals(50, dto.NetPrice);
                System.assertEquals(2, dto.DefaultLabourHours);
                break;
            }
        }
        System.assert(found, 'Created service should be in catalog.');
    }

    @IsTest
    static void getProductCatalogReturnsList() {
        Product__c prod = new Product__c(
            Product_Description__c = 'Test Prod',
            Price__c = 30,
            Tax_Rate__c = 0.1,
            Quantity_On_Hand__c = 10,
            Quantity_Reserved__c = 0
        );
        insert prod;

        Test.startTest();
        List<WorkOrderDetailController.ProductCatalogDto> result =
            WorkOrderDetailController.getProductCatalog();
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Expected at least one product.');
        Boolean found = false;
        for (WorkOrderDetailController.ProductCatalogDto dto : result) {
            if (dto.Id == prod.Id) {
                found = true;
                System.assertEquals(30, dto.NetPrice);
                break;
            }
        }
        System.assert(found, 'Created product should be in catalog.');
    }

    @IsTest
    static void addWorkOrderLineItemInsertsLine() {
        WorkOrder__c workOrder = createWorkOrderWithLines();
        Service__c service = [SELECT Id FROM Service__c LIMIT 1];

        Test.startTest();
        WorkOrderDetailController.addWorkOrderLineItem(
            workOrder.Id,
            'Service',
            null,
            service.Id,
            1.5,
            100,
            0
        );
        Test.stopTest();

        List<Work_Order_Line_Item__c> lines = [
            SELECT Id, Line_Type__c, Quantity__c
            FROM Work_Order_Line_Item__c
            WHERE Work_Order__c = :workOrder.Id
        ];
        System.assertEquals(3, lines.size(), 'Should have added one more line.');
    }

    @IsTest
    static void deleteWorkOrderLineItemDeletesLine() {
        WorkOrder__c workOrder = createWorkOrderWithLines();
        Id lineId = [SELECT Id FROM Work_Order_Line_Item__c WHERE Work_Order__c = :workOrder.Id LIMIT 1].Id;

        Test.startTest();
        WorkOrderDetailController.deleteWorkOrderLineItem(lineId);
        Test.stopTest();

        List<Work_Order_Line_Item__c> lines = [
            SELECT Id FROM Work_Order_Line_Item__c WHERE Work_Order__c = :workOrder.Id
        ];
        System.assertEquals(1, lines.size(), 'One line should be deleted.');
    }

    private static WorkOrder__c createWorkOrderWithLines() {
        String stamp = String.valueOf(DateTime.now().getTime());

        Account account = new Account(Name = 'Detail Test Account ' + stamp);
        insert account;

        Vehicle__c vehicle = new Vehicle__c(
            Name = '12345678901234567',
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
            Tax_Rate__c = 0,
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
