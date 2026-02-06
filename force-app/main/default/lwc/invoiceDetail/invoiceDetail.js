import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { refreshApex } from '@salesforce/apex';
import getInvoiceDetail from '@salesforce/apex/WorkOrderInvoiceController.getInvoiceDetail';
import updateInvoiceStatus from '@salesforce/apex/WorkOrderInvoiceController.updateInvoiceStatus';

const LINE_COLUMNS = [
    { label: 'ID', fieldName: 'name', type: 'text' },
    { label: 'Description', fieldName: 'description', type: 'text' },
    { label: 'Quantity', fieldName: 'quantityDisplay', type: 'text' },
    { label: 'Net Price', fieldName: 'unitPrice', type: 'currency' },
    { label: 'Total Net', fieldName: 'netTotal', type: 'currency' },
    { label: 'Tax Rate', fieldName: 'taxRate', type: 'percent' },
    { label: 'Total Gross', fieldName: 'grossTotal', type: 'currency' }
];

export default class InvoiceDetail extends LightningElement {
    @api invoiceId;

    columns = LINE_COLUMNS;
    detail;
    error;
    wiredDetailResult;

    @wire(getInvoiceDetail, { invoiceId: '$invoiceId' })
    wiredDetail(result) {
        this.wiredDetailResult = result;
        const { data, error } = result;
        if (data) {
            this.error = undefined;
            this.detail = {
                ...data,
                lines: (data.lines || []).map((line) => ({
                    ...line,
                    quantityDisplay:
                        line.lineType === 'Service' && line.quantity !== null
                            ? `${line.quantity} h`
                            : line.quantity
                }))
            };
        } else if (error) {
            this.detail = undefined;
            this.error = error;
        }
    }

    get hasData() {
        return Boolean(this.detail);
    }

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        return this.getErrorMessage(this.error);
    }

    get invoiceName() {
        return this.detail?.invoiceName ?? '—';
    }

    get createdByName() {
        return this.detail?.createdByName ?? '—';
    }

    get createdDate() {
        return this.detail?.createdDate ?? null;
    }

    get clientName() {
        return this.detail?.clientName ?? '—';
    }

    get status() {
        return this.detail?.status ?? '—';
    }

    get lines() {
        return this.detail?.lines ?? [];
    }

    get totalNet() {
        return this.detail?.totalNet ?? 0;
    }

    get totalGross() {
        return this.detail?.totalGross ?? 0;
    }

    get canApprove() {
        return this.status === 'Draft';
    }

    get canPay() {
        return this.status === 'Issued';
    }

    get canVoid() {
        return this.status === 'Draft' || this.status === 'Issued' || this.status === 'Paid';
    }

    get isApproveDisabled() {
        return !this.canApprove;
    }

    get isPaidDisabled() {
        return !this.canPay;
    }

    get isVoidDisabled() {
        return !this.canVoid;
    }

    async handleApprove() {
        await this.changeStatus('Issued');
    }

    async handlePaid() {
        await this.changeStatus('Paid');
    }

    async handleVoid() {
        await this.changeStatus('Void');
    }

    async changeStatus(targetStatus) {
        const confirmed = await LightningConfirm.open({
            message: `Change invoice ${this.invoiceName} status to ${targetStatus}?`,
            label: 'Confirm status change'
        });

        if (!confirmed) {
            return;
        }

        try {
            await updateInvoiceStatus({ invoiceId: this.invoiceId, newStatus: targetStatus });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invoice updated',
                    message: `Invoice ${this.invoiceName} set to ${targetStatus}.`,
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDetailResult);
            this.dispatchEvent(new CustomEvent('statuschange'));
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Update failed',
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    getErrorMessage(error) {
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }
}
