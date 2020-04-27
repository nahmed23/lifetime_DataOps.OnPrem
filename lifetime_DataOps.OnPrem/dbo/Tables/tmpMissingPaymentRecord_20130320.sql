CREATE TABLE [dbo].[tmpMissingPaymentRecord_20130320] (
    [PaymentID]        INT          NOT NULL,
    [ValPaymentTypeID] TINYINT      NOT NULL,
    [PaymentAmount]    MONEY        NOT NULL,
    [ApprovalCode]     VARCHAR (50) NULL,
    [MMSTranID]        INT          NULL,
    [InsertedDateTime] DATETIME     NULL,
    [UpdatedDateTime]  DATETIME     NULL,
    [TipAmount]        MONEY        NULL
);

