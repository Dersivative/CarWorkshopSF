import { createElement } from '@lwc/engine-dom';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import InvoiceDetail from 'c/invoiceDetail';

const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getInvoiceDetailAdapter = createApexTestWireAdapter();

jest.mock(
    '@salesforce/apex/WorkOrderInvoiceController.getInvoiceDetail',
    () => ({
        default: getInvoiceDetailAdapter
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/WorkOrderInvoiceController.updateInvoiceStatus',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    'lightning/confirm',
    () => ({
        open: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex',
    () => ({
        refreshApex: jest.fn()
    }),
    { virtual: true }
);

const DETAIL = {
    invoiceId: 'a01xx0000000001AAA',
    invoiceName: 'INV-0001',
    createdDate: '2025-02-01T10:00:00.000Z',
    createdByName: 'Test User',
    clientName: 'ACME',
    totalNet: 120.5,
    totalGross: 147.21,
    status: 'Draft',
    lines: [
        {
            lineId: 'a11xx0000000001AAA',
            name: 'Oil Change',
            lineType: 'Service',
            quantity: 2,
            unitPrice: 50,
            netTotal: 100,
            grossTotal: 123,
            taxRate: 0.23,
            description: 'Service desc'
        }
    ]
};

const flushPromises = () => Promise.resolve();

describe('c-invoice-detail', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders header and line items with quantity suffix', async () => {
        const element = createElement('c-invoice-detail', { is: InvoiceDetail });
        element.invoiceId = DETAIL.invoiceId;
        document.body.appendChild(element);

        getInvoiceDetailAdapter.emit(DETAIL);
        await flushPromises();

        const header = element.shadowRoot.querySelector('lightning-card');
        expect(header).not.toBeNull();

        const dataTable = element.shadowRoot.querySelector('lightning-datatable');
        expect(dataTable).not.toBeNull();
        expect(dataTable.data[0].quantityDisplay).toBe('2 h');
    });

    it('enables actions based on status', async () => {
        const element = createElement('c-invoice-detail', { is: InvoiceDetail });
        element.invoiceId = DETAIL.invoiceId;
        document.body.appendChild(element);

        getInvoiceDetailAdapter.emit(DETAIL);
        await flushPromises();

        const buttons = Array.from(element.shadowRoot.querySelectorAll('lightning-button'));
        const approveBtn = buttons.find((btn) => btn.label === 'Approve');
        const paidBtn = buttons.find((btn) => btn.label === 'Paid');
        const voidBtn = buttons.find((btn) => btn.label === 'Void');

        expect(approveBtn.disabled).toBe(false);
        expect(paidBtn.disabled).toBe(true);
        expect(voidBtn.disabled).toBe(false);
    });

    it('updates status after confirmation', async () => {
        const updateInvoiceStatus = require('@salesforce/apex/WorkOrderInvoiceController.updateInvoiceStatus')
            .default;
        LightningConfirm.open.mockResolvedValue(true);

        const element = createElement('c-invoice-detail', { is: InvoiceDetail });
        element.invoiceId = DETAIL.invoiceId;
        document.body.appendChild(element);

        const statusHandler = jest.fn();
        element.addEventListener('statuschange', statusHandler);

        getInvoiceDetailAdapter.emit(DETAIL);
        await flushPromises();

        const approveButton = Array.from(
            element.shadowRoot.querySelectorAll('lightning-button')
        ).find((btn) => btn.label === 'Approve');
        approveButton.click();

        await flushPromises();

        expect(LightningConfirm.open).toHaveBeenCalled();
        expect(updateInvoiceStatus).toHaveBeenCalledWith({
            invoiceId: DETAIL.invoiceId,
            newStatus: 'Issued'
        });
        expect(refreshApex).toHaveBeenCalled();
        expect(statusHandler).toHaveBeenCalled();
    });
});
