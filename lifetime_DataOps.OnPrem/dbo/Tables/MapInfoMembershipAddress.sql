CREATE TABLE [dbo].[MapInfoMembershipAddress] (
    [MapInfoMembershipAddressID] INT             IDENTITY (1, 1) NOT NULL,
    [MembershipID]               INT             NULL,
    [AddressLine1]               VARCHAR (50)    NULL,
    [AddressLine2]               VARCHAR (50)    NULL,
    [City]                       VARCHAR (50)    NULL,
    [StateAbbreviation]          VARCHAR (2)     NULL,
    [Zip]                        VARCHAR (11)    NULL,
    [Latitude]                   NUMERIC (18, 9) NULL,
    [Longitude]                  NUMERIC (18, 9) NULL,
    [GeoResults]                 VARCHAR (50)    NULL,
    [InsertedDateTime]           DATETIME        NULL,
    [UpdatedDateTime]            DATETIME        NULL,
    [AccessMembershipFlag]       BIT             DEFAULT ((0)) NOT NULL,
    [CheckInLevel]               TINYINT         NULL,
    CONSTRAINT [PK_MapInfoMembershipAddress_1] PRIMARY KEY NONCLUSTERED ([MapInfoMembershipAddressID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_MembershipID]
    ON [dbo].[MapInfoMembershipAddress]([MembershipID] ASC);

