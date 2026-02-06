trigger WorkOrderLineItemInventory on Work_Order_Line_Item__c (before insert, before update, after insert, after update, after delete) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            WorkOrderLineItemInventoryHandler.onBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            WorkOrderLineItemInventoryHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else {
        if (Trigger.isInsert) {
            WorkOrderLineItemInventoryHandler.onAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            WorkOrderLineItemInventoryHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            WorkOrderLineItemInventoryHandler.onAfterDelete(Trigger.old);
        }
    }
}
