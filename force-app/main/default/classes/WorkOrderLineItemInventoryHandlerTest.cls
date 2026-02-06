@IsTest
private class WorkOrderLineItemInventoryHandlerTest {
    @IsTest
    static void afterInsertIncrementsReserved() {
        Product__c product = createProduct(10, 0);
        WorkOrder__c workOrder = createWorkOrder();

        Test.startTest();
        Work_Order_Line_Item__c line = new Work_Order_Line_Item__c(
            Work_Order__c = workOrder.Id,
            Line_Type__c = 'Product',
            Product__c = product.Id,
            Quantity__c = 3,
            Unit_Price__c = 10,
            Tax_Rate__c = 0
        );
        insert line;
        Test.stopTest();

        Product__c updated = [SELECT Quantity_Reserved__c FROM Product__c WHERE Id = :product.Id];
        System.assertEquals(3, updated.Quantity_Reserved__c, 'Reserved should increase by line quantity.');
    }

    @IsTest
    static void beforeInsertBlocksWhenInsufficientAvailable() {
        Product__c product = createProduct(2, 0);
        WorkOrder__c workOrder = createWorkOrder();

        Boolean failed = false;
        Test.startTest();
        try {
            Work_Order_Line_Item__c line = new Work_Order_Line_Item__c(
                Work_Order__c = workOrder.Id,
                Line_Type__c = 'Product',
                Product__c = product.Id,
                Quantity__c = 5,
                Unit_Price__c = 10,
                Tax_Rate__c = 0
            );
            insert line;
        } catch (DmlException e) {
            failed = true;
            System.assert(e.getMessage().contains('Insufficient quantity available'), 'Should fail with insufficient quantity.');
        }
        Test.stopTest();

        System.assert(failed, 'Insert should fail when quantity exceeds available.');
    }

    @IsTest
    static void afterDeleteDecrementsReserved() {
        Product__c product = createProduct(10, 0);
        WorkOrder__c workOrder = createWorkOrder();
        Work_Order_Line_Item__c line = new Work_Order_Line_Item__c(
            Work_Order__c = workOrder.Id,
            Line_Type__c = 'Product',
            Product__c = product.Id,
            Quantity__c = 4,
            Unit_Price__c = 10,
            Tax_Rate__c = 0
        );
        insert line;
        System.assertEquals(4, [SELECT Quantity_Reserved__c FROM Product__c WHERE Id = :product.Id].Quantity_Reserved__c);

        Test.startTest();
        delete line;
        Test.stopTest();

        Product__c updated = [SELECT Quantity_Reserved__c FROM Product__c WHERE Id = :product.Id];
        System.assertEquals(0, updated.Quantity_Reserved__c, 'Reserved should decrease after line delete.');
    }

    private static Product__c createProduct(Decimal onHand, Decimal reserved) {
        Product__c p = new Product__c(
            Product_Description__c = 'Test Product ' + String.valueOf(DateTime.now().getTime()),
            Price__c = 10,
            Tax_Rate__c = 0,
            Quantity_On_Hand__c = onHand,
            Quantity_Reserved__c = reserved
        );
        insert p;
        return p;
    }

    private static WorkOrder__c createWorkOrder() {
        Account acc = new Account(Name = 'Test Acc');
        insert acc;
        Vehicle__c v = new Vehicle__c(Name = '12345678901234567', Account__c = acc.Id, Plate__c = 'PLT-1');
        insert v;
        Visit__c visit = new Visit__c(Account__c = acc.Id, Vehicle__c = v.Id);
        insert visit;
        WorkOrder__c wo = new WorkOrder__c(Visit__c = visit.Id);
        insert wo;
        return wo;
    }
}
