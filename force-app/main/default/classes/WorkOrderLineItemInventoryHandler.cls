public with sharing class WorkOrderLineItemInventoryHandler {
    public static void onBeforeInsert(List<Work_Order_Line_Item__c> newList) {
        Map<Id, Decimal> productIdToNewQty = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : newList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) {
                continue;
            }
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0;
            productIdToNewQty.put(
                line.Product__c,
                (productIdToNewQty.get(line.Product__c) != null ? productIdToNewQty.get(line.Product__c) : 0) + qty
            );
        }
        if (productIdToNewQty.isEmpty()) {
            return;
        }
        Map<Id, Product__c> products = new Map<Id, Product__c>([
            SELECT Id, Quantity_Reserved__c, Quantity_On_Hand__c
            FROM Product__c
            WHERE Id IN :productIdToNewQty.keySet()
        ]);
        for (Work_Order_Line_Item__c line : newList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue;
            Product__c p = products.get(line.Product__c);
            if (p == null) continue;
            Decimal currentReserved = p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0;
            Decimal onHand = p.Quantity_On_Hand__c != null ? p.Quantity_On_Hand__c : 0;
            Decimal totalNewForProduct = productIdToNewQty.get(line.Product__c);
            if (currentReserved + totalNewForProduct > onHand) {
                line.addError(
                    'Insufficient quantity available for this product. Available: ' +
                    (onHand - currentReserved) + ', requested: ' + totalNewForProduct
                );
                return;
            }
        }
    }

    public static void onBeforeUpdate(
        List<Work_Order_Line_Item__c> newList,
        Map<Id, Work_Order_Line_Item__c> oldMap
    ) {
        Map<Id, Decimal> productIdToDelta = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : newList) {
            Work_Order_Line_Item__c oldLine = oldMap.get(line.Id);
            if (oldLine == null) continue;
            if (line.Line_Type__c != 'Product') continue;
            Decimal newQty = (line.Quantity__c != null ? line.Quantity__c : 0);
            Decimal oldQty = (oldLine.Quantity__c != null ? oldLine.Quantity__c : 0);
            Id newProductId = line.Product__c;
            Id oldProductId = oldLine.Product__c;
            if (newProductId != null) {
                Decimal d = productIdToDelta.get(newProductId) != null ? productIdToDelta.get(newProductId) : 0;
                productIdToDelta.put(newProductId, d + newQty);
            }
            if (oldProductId != null) {
                Decimal d = productIdToDelta.get(oldProductId) != null ? productIdToDelta.get(oldProductId) : 0;
                productIdToDelta.put(oldProductId, d - oldQty);
            }
        }
        if (productIdToDelta.isEmpty()) return;
        Map<Id, Product__c> products = new Map<Id, Product__c>([
            SELECT Id, Quantity_Reserved__c, Quantity_On_Hand__c
            FROM Product__c
            WHERE Id IN :productIdToDelta.keySet()
        ]);
        for (Id productId : productIdToDelta.keySet()) {
            Decimal delta = productIdToDelta.get(productId);
            Product__c p = products.get(productId);
            if (p == null) continue;
            Decimal currentReserved = p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0;
            Decimal onHand = p.Quantity_On_Hand__c != null ? p.Quantity_On_Hand__c : 0;
            if (currentReserved + delta > onHand) {
                for (Work_Order_Line_Item__c line : newList) {
                    if (line.Product__c == productId) {
                        line.addError(
                            'Insufficient quantity available for this product. Available: ' +
                            (onHand - currentReserved) + ', requested change: ' + delta
                        );
                        return;
                    }
                }
            }
        }
    }

    public static void onAfterInsert(List<Work_Order_Line_Item__c> newList) {
        Map<Id, Decimal> productIdToAdd = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : newList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue;
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0;
            productIdToAdd.put(
                line.Product__c,
                (productIdToAdd.get(line.Product__c) != null ? productIdToAdd.get(line.Product__c) : 0) + qty
            );
        }
        if (productIdToAdd.isEmpty()) return;
        List<Product__c> toUpdate = new List<Product__c>();
        for (Product__c p : [SELECT Id, Quantity_Reserved__c FROM Product__c WHERE Id IN :productIdToAdd.keySet()]) {
            Decimal addQty = productIdToAdd.get(p.Id);
            p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) + addQty;
            toUpdate.add(p);
        }
        update toUpdate;
    }

    public static void onAfterUpdate(
        List<Work_Order_Line_Item__c> newList,
        Map<Id, Work_Order_Line_Item__c> oldMap
    ) {
        Map<Id, Decimal> productIdToDelta = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : newList) {
            Work_Order_Line_Item__c oldLine = oldMap.get(line.Id);
            if (oldLine == null) continue;
            if (line.Line_Type__c != 'Product') continue;
            Decimal newQty = line.Quantity__c != null ? line.Quantity__c : 0;
            Decimal oldQty = oldLine.Quantity__c != null ? oldLine.Quantity__c : 0;
            Id newProductId = line.Product__c;
            Id oldProductId = oldLine.Product__c;
            if (newProductId != null) {
                Decimal d = productIdToDelta.get(newProductId) != null ? productIdToDelta.get(newProductId) : 0;
                productIdToDelta.put(newProductId, d + newQty);
            }
            if (oldProductId != null) {
                Decimal d = productIdToDelta.get(oldProductId) != null ? productIdToDelta.get(oldProductId) : 0;
                productIdToDelta.put(oldProductId, d - oldQty);
            }
        }
        if (productIdToDelta.isEmpty()) return;
        List<Product__c> toUpdate = new List<Product__c>();
        for (Product__c p : [SELECT Id, Quantity_Reserved__c FROM Product__c WHERE Id IN :productIdToDelta.keySet()]) {
            Decimal delta = productIdToDelta.get(p.Id);
            if (delta == 0) continue;
            p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) + delta;
            toUpdate.add(p);
        }
        update toUpdate;
    }

    public static void onAfterDelete(List<Work_Order_Line_Item__c> oldList) {
        Map<Id, Decimal> productIdToSub = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : oldList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue;
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0;
            productIdToSub.put(
                line.Product__c,
                (productIdToSub.get(line.Product__c) != null ? productIdToSub.get(line.Product__c) : 0) + qty
            );
        }
        if (productIdToSub.isEmpty()) return;
        List<Product__c> toUpdate = new List<Product__c>();
        for (Product__c p : [SELECT Id, Quantity_Reserved__c FROM Product__c WHERE Id IN :productIdToSub.keySet()]) {
            Decimal subQty = productIdToSub.get(p.Id);
            p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) - subQty;
            if (p.Quantity_Reserved__c < 0) {
                p.Quantity_Reserved__c = 0;
            }
            toUpdate.add(p);
        }
        update toUpdate;
    }
}
