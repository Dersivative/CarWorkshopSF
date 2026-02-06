import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { refreshApex } from '@salesforce/apex';
import getInvoices from '@salesforce/apex/WorkOrderInvoiceController.getInvoices';
import getInvoiceCreatedByOptions from '@salesforce/apex/WorkOrderInvoiceController.getInvoiceCreatedByOptions';
import getInvoiceAccountOptions from '@salesforce/apex/WorkOrderInvoiceController.getInvoiceAccountOptions';
import updateInvoiceStatus from '@salesforce/apex/WorkOrderInvoiceController.updateInvoiceStatus';

const ACTION_APPROVE = 'approve';
const ACTION_VOID = 'void';
const ACTION_PAID = 'paid';
const ACTION_VIEW = 'view';

const COLUMNS = [
    {
        label: 'Invoice Number',
        fieldName: 'invoiceUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
    },
    {
        label: 'Issued On',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
    },
    { label: 'Issued By', fieldName: 'createdByName', type: 'text' },
    { label: 'Client', fieldName: 'accountName', type: 'text' },
    { label: 'Net Total', fieldName: 'Invoice_Net_Total__c', type: 'currency' },
    { label: 'Status', fieldName: 'Invoice_Status__c', type: 'text' },
    {
        label: 'View',
        type: 'button',
        typeAttributes: {
            label: 'View',
            name: ACTION_VIEW,
            variant: 'base'
        }
    },
    {
        type: 'action',
        typeAttributes: { rowActions: { fieldName: 'availableActions' } }
    }
];

export default class InvoiceList extends LightningElement {
    columns = COLUMNS;
    invoices = [];
    error;
    wiredInvoicesResult;
    createdByOptions = [];
    accountOptions = [];
    selectedCreatedById = '';
    selectedAccountId = '';
    isDetailOpen = false;
    selectedInvoiceId;

    @wire(getInvoiceCreatedByOptions)
    wiredCreatedByOptions({ data, error }) {
        if (data) {
            this.createdByOptions = data;
        } else if (error) {
            this.createdByOptions = [];
        }
    }

    @wire(getInvoiceAccountOptions)
    wiredAccountOptions({ data, error }) {
        if (data) {
            this.accountOptions = data;
        } else if (error) {
            this.accountOptions = [];
        }
    }

    @wire(getInvoices, { createdById: '$createdByIdParam', accountId: '$accountIdParam' })
    wiredInvoices(result) {
        this.wiredInvoicesResult = result;
        const { data, error } = result;
        if (data) {
            this.error = undefined;
            this.invoices = data.map((invoice) => ({
                ...invoice,
                invoiceUrl: '/' + invoice.Id,
                createdByName: invoice.CreatedBy?.Name ?? '—',
                accountName: invoice.Work_Order__r?.Visit__r?.Account__r?.Name ?? '—',
                availableActions: this.getActionsForStatus(invoice.Invoice_Status__c)
            }));
        } else if (error) {
            this.invoices = [];
            this.error = error;
        }
    }

    get createdByIdParam() {
        return this.selectedCreatedById || null;
    }

    get accountIdParam() {
        return this.selectedAccountId || null;
    }

    get createdByFilterOptions() {
        return [{ label: 'All', value: '' }, ...this.createdByOptions];
    }

    get accountFilterOptions() {
        return [{ label: 'All', value: '' }, ...this.accountOptions];
    }

    handleCreatedByChange(event) {
        this.selectedCreatedById = event.detail.value;
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value;
    }

    getActionsForStatus(status) {
        if (status === 'Draft') {
            return [
                { label: 'Approve', name: ACTION_APPROVE },
                { label: 'Void', name: ACTION_VOID }
            ];
        }
        if (status === 'Issued') {
            return [
                { label: 'Paid', name: ACTION_PAID },
                { label: 'Void', name: ACTION_VOID }
            ];
        }
        if (status === 'Paid') {
            return [{ label: 'Void', name: ACTION_VOID }];
        }
        return [];
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === ACTION_VIEW) {
            this.selectedInvoiceId = row.Id;
            this.isDetailOpen = true;
            return;
        }
        const targetStatus = this.mapActionToStatus(actionName);
        if (!targetStatus) {
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: `Change invoice ${row.Name} status to ${targetStatus}?`,
            label: 'Confirm status change'
        });

        if (!confirmed) {
            return;
        }

        try {
            await updateInvoiceStatus({ invoiceId: row.Id, newStatus: targetStatus });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invoice updated',
                    message: `Invoice ${row.Name} set to ${targetStatus}.`,
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredInvoicesResult);
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

    mapActionToStatus(actionName) {
        if (actionName === ACTION_APPROVE) {
            return 'Issued';
        }
        if (actionName === ACTION_VOID) {
            return 'Void';
        }
        if (actionName === ACTION_PAID) {
            return 'Paid';
        }
        return null;
    }

    handleCloseDetail() {
        this.isDetailOpen = false;
        this.selectedInvoiceId = null;
    }

    async handleDetailStatusChange() {
        await refreshApex(this.wiredInvoicesResult);
    }

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        if (this.error.body && typeof this.error.body.message === 'string') {
            return this.error.body.message;
        }
        return this.error.message || 'Unknown error';
    }
}
