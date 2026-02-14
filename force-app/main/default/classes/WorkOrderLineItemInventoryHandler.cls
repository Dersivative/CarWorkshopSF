//zestaw metod używanych przez trigger WorkOrderLineItemInventory
// do zapewnienia ze available quantity jest zawsze >= 0 oraz rowne qty_on_hand - qty_reserved
public with sharing class WorkOrderLineItemInventoryHandler {
    /**
     * sprawdza, czy liczba produktów jest wystarczająca, by pokryć
     * nowe work order line items (agregacja ilości po produkcie). Blokuje insert, jeśli
     * currentReserved + suma nowych ilości > qty_on_hand dla któregoś produktu.
     */
    public static void onBeforeInsert(List<Work_Order_Line_Item__c> newList) {
        Map<Id, Decimal> productIdToReserveQty = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : newList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) { // pomijam usługi
                continue;
            }
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0; // obsługa null (nie powinno się zdarzyć)
            productIdToReserveQty.put(
                line.Product__c,
                (productIdToReserveQty.get(line.Product__c) != null ? productIdToReserveQty.get(line.Product__c) : 0) + qty // suma qty per produkt
            );
        }
        if (productIdToReserveQty.isEmpty()) {
            return;
        }
        Map<Id, Product__c> products = new Map<Id, Product__c>([
            SELECT Id, Quantity_Reserved__c, Quantity_On_Hand__c
            FROM Product__c
            WHERE Id IN :productIdToReserveQty.keySet()
        ]);
        for (Work_Order_Line_Item__c line : newList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue; 
            Product__c p = products.get(line.Product__c);
            if (p == null) continue;

            // pobieram aktualne rezerwacje i ilość na stanie dla produktu
            Decimal currentReserved = p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0;
            Decimal onHand = p.Quantity_On_Hand__c != null ? p.Quantity_On_Hand__c : 0;
            Decimal totalNewForProduct = productIdToReserveQty.get(line.Product__c);
            // sprawdzam czy suma aktualnych rezerwacji i nowych ilości przekracza ilość na stanie
            if (currentReserved + totalNewForProduct > onHand) {
                line.addError(
                    'Insufficient quantity available for this product. Available: ' +
                    (onHand - currentReserved) + ', requested: ' + totalNewForProduct
                );
                return;
            }
        }
    }

    /**
     * sprawdza, czy zmiana ilości / produktu nie spowoduje
     * przekroczenia dostępnej ilości (qty_on_hand - qty_reserved) dla żadnego produktu.
     * Liczy roznice  rezerwacji per produkt
     */
    public static void onBeforeUpdate(
        List<Work_Order_Line_Item__c> newList,
        Map<Id, Work_Order_Line_Item__c> oldMap
    ) {
        Map<Id, Decimal> productIdToDiff = new Map<Id, Decimal>();
        // roznice rezerwacji per produkt
        for (Work_Order_Line_Item__c line : newList) {
            Work_Order_Line_Item__c oldLine = oldMap.get(line.Id);
            if (oldLine == null) continue; // bez usunietych linii
            if (line.Line_Type__c != 'Product') continue;

            Decimal newQty = (line.Quantity__c != null ? line.Quantity__c : 0);
            Decimal oldQty = (oldLine.Quantity__c != null ? oldLine.Quantity__c : 0);
            Id newProductId = line.Product__c;
            Id oldProductId = oldLine.Product__c;

            if (newProductId != null) { // nie powinno sie zdarzyć, bo w drugim triggerze wymuszam, by id produktu było nie null jeśli typ linii jest Product
                Decimal d = productIdToDiff.get(newProductId) != null ? productIdToDiff.get(newProductId) : 0;
                productIdToDiff.put(newProductId, d + newQty);
            }
            if (oldProductId != null) {
                Decimal d = productIdToDiff.get(oldProductId) != null ? productIdToDiff.get(oldProductId) : 0;
                productIdToDiff.put(oldProductId, d - oldQty);
            }
        }
        if (productIdToDiff.isEmpty()) return;
        // pobieram produkty z bazy danych
        Map<Id, Product__c> products = new Map<Id, Product__c>([
            SELECT Id, Quantity_Reserved__c, Quantity_On_Hand__c
            FROM Product__c
            WHERE Id IN :productIdToDiff.keySet()
        ]);
        for (Id productId : productIdToDiff.keySet()) {
            Decimal diff = productIdToDiff.get(productId);
            Product__c p = products.get(productId);
            if (p == null) continue; // produkt nie istnieje

            // licze aktualne rezerwacje i ilość na stanie dla produktu
            Decimal currentReserved = p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0;
            Decimal onHand = p.Quantity_On_Hand__c != null ? p.Quantity_On_Hand__c : 0;
            if (currentReserved + diff > onHand) {
                for (Work_Order_Line_Item__c line : newList) {
                    if (line.Product__c == productId) {
                        line.addError(
                            'Insufficient quantity available for this product. Available: ' +
                            (onHand - currentReserved) + ', requested change: ' + diff
                        );
                        return;
                    }
                }
            }
        }
    }

    /**
     * zwiększa Quantity_Reserved__c na Product__c o sumę ilości
     * z nowych pozycji typu Product (agregacja po produkcie).
     */
    public static void onAfterInsert(List<Work_Order_Line_Item__c> newList) {
        Map<Id, Decimal> productIdToAdd = new Map<Id, Decimal>();
        for (Work_Order_Line_Item__c line : newList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue;
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0;
            productIdToAdd.put(
                line.Product__c,
                (productIdToAdd.get(line.Product__c) != null ? productIdToAdd.get(line.Product__c) : 0) + qty // suma qty per produkt
            );
        }
        if (productIdToAdd.isEmpty()) return;
        List<Product__c> toUpdate = new List<Product__c>(); // lista produktów do aktualizacji
        for (Product__c p : [SELECT Id, Quantity_Reserved__c FROM Product__c WHERE Id IN :productIdToAdd.keySet()]) {
            Decimal addQty = productIdToAdd.get(p.Id);
            p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) + addQty; // dodawane rezerwacje z nowych linii
            toUpdate.add(p);
        }
        update toUpdate; // aktualizuję rezerwacje produktów
    }

    /**
     * aktualizuje Quantity_Reserved__c na Product__c 
     * nowa ilość minus stara ilość, zmiana produktu = + na nowy produkt, - na stary
     */
    public static void onAfterUpdate(
        List<Work_Order_Line_Item__c> newList,
        Map<Id, Work_Order_Line_Item__c> oldMap
    ) {
        Map<Id, Decimal> productIdToDiff = new Map<Id, Decimal>();
        // roznice rezerwacji per produkt
        for (Work_Order_Line_Item__c line : newList) {
            Work_Order_Line_Item__c oldLine = oldMap.get(line.Id);
            if (oldLine == null) continue; // bez usunietych linii
            if (line.Line_Type__c != 'Product') continue;
            Decimal newQty = line.Quantity__c != null ? line.Quantity__c : 0;
            Decimal oldQty = oldLine.Quantity__c != null ? oldLine.Quantity__c : 0;
            Id newProductId = line.Product__c;
            Id oldProductId = oldLine.Product__c;
            if (newProductId != null) { // nie powinno sie zdarzyć, inny triger wymusz
                Decimal d = productIdToDiff.get(newProductId) != null ? productIdToDiff.get(newProductId) : 0;
                productIdToDiff.put(newProductId, d + newQty);
            }
            if (oldProductId != null) { // nie powinno sie zdarzyć
                Decimal d = productIdToDiff.get(oldProductId) != null ? productIdToDiff.get(oldProductId) : 0;
                productIdToDiff.put(oldProductId, d - oldQty);
            }
        }
        if (productIdToDiff.isEmpty()) return;
        // jak wyzej
        List<Product__c> toUpdate = new List<Product__c>();
        for (Product__c p : [SELECT Id, Quantity_Reserved__c FROM Product__c WHERE Id IN :productIdToDiff.keySet()]) {
            Decimal diff = productIdToDiff.get(p.Id);
            if (diff == 0) continue;
            p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) + diff; // aktualizuję rezerwację
            toUpdate.add(p);
        }
        update toUpdate;
    }

    /**
     * zmniejsza Quantity_Reserved__c na Product__c o sumę ilości
     * z usuniętych pozycji typu Product (agregacja po produkcie). Nie zezwala na wartość < 0.
     */
    public static void onAfterDelete(List<Work_Order_Line_Item__c> oldList) {
        Map<Id, Decimal> productIdToSub = new Map<Id, Decimal>(); // roznice rezerwacji per produkt
        for (Work_Order_Line_Item__c line : oldList) {
            if (line.Line_Type__c != 'Product' || line.Product__c == null) continue;
            Decimal qty = line.Quantity__c != null ? line.Quantity__c : 0;
            productIdToSub.put(
                line.Product__c,
                (productIdToSub.get(line.Product__c) != null ? productIdToSub.get(line.Product__c) : 0) + qty // suma qty per produkt
            );
        }
        if (productIdToSub.isEmpty()) return;
        List<Product__c> toUpdate = new List<Product__c>();
        for (Product__c p : [SELECT Id, Quantity_Reserved__c FROM Product__c WHERE Id IN :productIdToSub.keySet()]) {
            Decimal subQty = productIdToSub.get(p.Id);
            p.Quantity_Reserved__c = (p.Quantity_Reserved__c != null ? p.Quantity_Reserved__c : 0) - subQty; // odejmowane rezerwacje z usunietych linii
            if (p.Quantity_Reserved__c < 0) {
                p.Quantity_Reserved__c = 0;
            }
            toUpdate.add(p);
        }
        update toUpdate;
    }
}
