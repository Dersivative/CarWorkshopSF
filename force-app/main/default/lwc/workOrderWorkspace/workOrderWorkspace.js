import { LightningElement } from 'lwc';

export default class WorkOrderWorkspace extends LightningElement {
    selectedWorkOrderId;

    handleWorkOrderSelect(event) {
        this.selectedWorkOrderId = event.detail.workOrderId;
    }
}
