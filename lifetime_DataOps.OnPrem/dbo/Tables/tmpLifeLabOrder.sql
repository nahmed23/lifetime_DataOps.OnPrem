CREATE TABLE [dbo].[tmpLifeLabOrder] (
    [life_lab_order_id]       INT           NOT NULL,
    [llo_party_encryption_id] INT           NOT NULL,
    [llo_product_id]          INT           NOT NULL,
    [state_status]            NVARCHAR (39) NOT NULL,
    [state_status_datetime]   SMALLDATETIME NULL,
    [order_create_datetime]   SMALLDATETIME NULL,
    [mms_transaction_id]      NVARCHAR (51) NULL,
    [update_datetime]         SMALLDATETIME NULL,
    [update_userid]           NVARCHAR (31) NOT NULL
);

