@IsTest
private class WorkOrderLineItemConverterTest {
    private static final String LINE_TYPE_PRODUCT = 'Product';
    private static final String LINE_TYPE_SERVICE = 'Service';

    @IsTest
    static void convertCopiesValuesForSingleInvoice() {
        TestData data = createTestData(1);
        Work_Order_Line_Item__c productLine = buildProductLine(data.workOrders[0].Id, data.product.Id);
        Work_Order_Line_Item__c serviceLine = buildServiceLine(data.workOrders[0].Id, data.service.Id);

        List<Invoice_Line_Item__c> results = WorkOrderLineItemConverter.convert(
            new List<Work_Order_Line_Item__c>{ productLine, serviceLine },
            data.invoices[0].Id
        );

        System.assertEquals(2, results.size());
        Map<String, Work_Order_Line_Item__c> sourceByType = new Map<String, Work_Order_Line_Item__c>{
            LINE_TYPE_PRODUCT => productLine,
            LINE_TYPE_SERVICE => serviceLine
        };

        for (Invoice_Line_Item__c result : results) {
            Work_Order_Line_Item__c source = sourceByType.get(result.Line_Type__c);
            System.assertNotEquals(null, source, 'Unexpected line type returned.');
            System.assertEquals(data.invoices[0].Id, result.Invoice__c);
            System.assertEquals(source.Product__c, result.Product__c);
            System.assertEquals(source.Service__c, result.Service__c);
            System.assertEquals(source.Quantity__c, result.Quantity__c);
            System.assertEquals(source.Unit_Price__c, result.Unit_Price__c);
            System.assertEquals(source.Tax_Rate__c, result.Tax_Rate__c);
        }
    }

    @IsTest
    static void convertWithMappingDistributesInvoiceIds() {
        TestData data = createTestData(2);
        Work_Order_Line_Item__c lineOne = buildProductLine(data.workOrders[0].Id, data.product.Id);
        Work_Order_Line_Item__c lineTwo = buildServiceLine(data.workOrders[1].Id, data.service.Id);

        Map<Id, Id> mapping = new Map<Id, Id>{
            data.workOrders[0].Id => data.invoices[0].Id,
            data.workOrders[1].Id => data.invoices[1].Id
        };

        List<Invoice_Line_Item__c> results = WorkOrderLineItemConverter.convertWithMapping(
            new List<Work_Order_Line_Item__c>{ lineOne, lineTwo },
            mapping
        );

        System.assertEquals(2, results.size());
        Map<String, Work_Order_Line_Item__c> linesByType = new Map<String, Work_Order_Line_Item__c>{
            lineOne.Line_Type__c => lineOne,
            lineTwo.Line_Type__c => lineTwo
        };

        for (Invoice_Line_Item__c result : results) {
            Work_Order_Line_Item__c source = linesByType.get(result.Line_Type__c);
            System.assertNotEquals(null, source, 'Unexpected line type returned.');
            System.assertEquals(mapping.get(source.Work_Order__c), result.Invoice__c);
        }
    }

    @IsTest
    static void convertValidatesInvoiceId() {
        TestData data = createTestData(1);
        Work_Order_Line_Item__c productLine = buildProductLine(data.workOrders[0].Id, data.product.Id);

        Boolean exceptionThrown = false;
        try {
            WorkOrderLineItemConverter.convert(new List<Work_Order_Line_Item__c>{ productLine }, null);
        } catch (IllegalArgumentException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Invoice Id is required'), ex.getMessage());
        }
        System.assert(exceptionThrown, 'Expected IllegalArgumentException for missing invoice Id.');
    }

    @IsTest
    static void convertWithMappingValidatesMissingEntries() {
        TestData data = createTestData(2);
        Work_Order_Line_Item__c missingMappedLine = buildServiceLine(data.workOrders[1].Id, data.service.Id);

        Map<Id, Id> incompleteMapping = new Map<Id, Id>{
            data.workOrders[0].Id => data.invoices[0].Id
        };

        Boolean exceptionThrown = false;
        try {
            WorkOrderLineItemConverter.convertWithMapping(
                new List<Work_Order_Line_Item__c>{ missingMappedLine },
                incompleteMapping
            );
        } catch (IllegalArgumentException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Missing invoice mapping'), ex.getMessage());
        }
        System.assert(exceptionThrown, 'Expected IllegalArgumentException when mapping is missing.');
    }

    private class TestData {
        Account account;
        Vehicle__c vehicle;
        Visit__c visit;
        List<WorkOrder__c> workOrders;
        List<Invoice__c> invoices;
        Product__c product;
        Service__c service;
    }

    private static TestData createTestData(Integer workOrderCount) {
        TestData data = new TestData();
        data.account = createAccount();
        data.vehicle = createVehicle(data.account.Id);
        data.visit = createVisit(data.account.Id, data.vehicle.Id);
        data.product = createProduct();
        data.service = createService();
        data.workOrders = new List<WorkOrder__c>();
        data.invoices = new List<Invoice__c>();

        List<WorkOrder__c> workOrdersToInsert = new List<WorkOrder__c>();
        for (Integer i = 0; i < workOrderCount; i++) {
            workOrdersToInsert.add(new WorkOrder__c(Visit__c = data.visit.Id));
        }
        insert workOrdersToInsert;
        data.workOrders.addAll(workOrdersToInsert);

        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
        for (WorkOrder__c workOrder : data.workOrders) {
            invoicesToInsert.add(new Invoice__c(Work_Order__c = workOrder.Id));
        }
        insert invoicesToInsert;
        data.invoices.addAll(invoicesToInsert);

        return data;
    }

    private static Account createAccount() {
        Account account = new Account(Name = 'Test Account ' + String.valueOf(DateTime.now().getTime()));
        insert account;
        return account;
    }

    private static Vehicle__c createVehicle(Id accountId) {
        Vehicle__c vehicle = new Vehicle__c(
            Name = '12345678901234567',
            Account__c = accountId,
            Plate__c = 'PL' + String.valueOf(Math.mod(DateTime.now().getTime(), 1000000))
        );
        insert vehicle;
        return vehicle;
    }

    private static Visit__c createVisit(Id accountId, Id vehicleId) {
        Visit__c visit = new Visit__c(
            Account__c = accountId,
            Vehicle__c = vehicleId,
            Odometer_km__c = 12345
        );
        insert visit;
        return visit;
    }

    private static Product__c createProduct() {
        Product__c product = new Product__c(
            Price__c = 100,
            Quantity_On_Hand__c = 50,
            Tax_Rate__c = 0.23,
            Product_Description__c = 'Product ' + String.valueOf(DateTime.now().getTime())
        );
        insert product;
        return product;
    }

    private static Service__c createService() {
        Service__c service = new Service__c(
            Default_Labour_Hours__c = 2,
            Hourly_Rate__c = 80,
            Tax_Rate__c = 0.23,
            Service_Description__c = 'Service ' + String.valueOf(DateTime.now().getTime())
        );
        insert service;
        return service;
    }

    private static Work_Order_Line_Item__c buildProductLine(Id workOrderId, Id productId) {
        return new Work_Order_Line_Item__c(
            Work_Order__c = workOrderId,
            Line_Type__c = LINE_TYPE_PRODUCT,
            Product__c = productId,
            Quantity__c = 2,
            Unit_Price__c = 100,
            Tax_Rate__c = 0.23
        );
    }

    private static Work_Order_Line_Item__c buildServiceLine(Id workOrderId, Id serviceId) {
        return new Work_Order_Line_Item__c(
            Work_Order__c = workOrderId,
            Line_Type__c = LINE_TYPE_SERVICE,
            Service__c = serviceId,
            Quantity__c = 1,
            Unit_Price__c = 80,
            Tax_Rate__c = 0.23
        );
    }
}