CREATE TABLE [dbo].[PTProductGroupRevenue] (
    [PTProductGroupRevenueID] INT             IDENTITY (1, 1) NOT NULL,
    [ClubID]                  INT             NULL,
    [EmployeeID]              INT             NULL,
    [PayPeriod]               VARCHAR (7)     NULL,
    [SalesRevenueTotal]       NUMERIC (12, 2) NULL,
    [ServiceRevenueTotal]     NUMERIC (12, 2) NULL,
    [ValPTProductGroupID]     SMALLINT        NULL,
    [InsertedDateTime]        DATETIME        CONSTRAINT [DF_PTProductGroupRevenue_InsertedDateTime] DEFAULT (getdate()) NULL,
    [InsertUser]              VARCHAR (50)    CONSTRAINT [DF_PTProductGroupRevenue_InsertUser] DEFAULT (suser_sname()) NULL,
    [BatchID]                 INT             NULL,
    [UpdatedDatetime]         DATETIME        NULL,
    [UpdatedUser]             VARCHAR (50)    NULL,
    CONSTRAINT [PK_PTProductGroupRevenue] PRIMARY KEY CLUSTERED ([PTProductGroupRevenueID] ASC)
);


GO


CREATE TRIGGER [uPTProductGroupRevenue] ON [dbo].[PTProductGroupRevenue] FOR UPDATE
AS
BEGIN
  SET XACT_ABORT ON
  SET NOCOUNT ON


  UPDATE PTProductGroupRevenue
  SET UpdatedDateTime = getdate(),
      UpdatedUser = suser_sname() 
  FROM  PTProductGroupRevenue A JOIN DELETED B ON A.PTProductGroupRevenueID = B.PTProductGroupRevenueID

END

