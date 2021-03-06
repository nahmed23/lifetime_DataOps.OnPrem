﻿CREATE TABLE [dbo].[AcquisitionMember] (
    [AcquisitionMemberID]        INT           IDENTITY (1, 1) NOT FOR REPLICATION NOT NULL,
    [ExternalMemberID]           VARCHAR (50)  NOT NULL,
    [ExternalMembershipID]       VARCHAR (50)  NOT NULL,
    [FirstName]                  VARCHAR (50)  NOT NULL,
    [LastName]                   VARCHAR (50)  NOT NULL,
    [Gender]                     CHAR (1)      NULL,
    [DOB]                        DATETIME      NOT NULL,
    [ValMemberTypeID]            TINYINT       NOT NULL,
    [EmailAddress]               VARCHAR (140) NULL,
    [MembershipTypeID]           INT           NULL,
    [ClubID]                     INT           NULL,
    [JoinDate]                   DATETIME      NULL,
    [ActivationDate]             DATETIME      NULL,
    [TerminationDate]            DATETIME      NULL,
    [ValTerminationReasonID]     TINYINT       NULL,
    [AssessJrMemberDuesFlag]     BIT           NULL,
    [ExternalMembershipPrice]    MONEY         NULL,
    [QualifiedSalesPromotionID]  INT           NULL,
    [AddressLine1]               VARCHAR (50)  NULL,
    [AddressLine2]               VARCHAR (50)  NULL,
    [City]                       VARCHAR (50)  NULL,
    [State]                      VARCHAR (2)   NULL,
    [Zip]                        VARCHAR (11)  NULL,
    [ValCountryID]               TINYINT       NULL,
    [HomePhone]                  VARCHAR (12)  NULL,
    [WorkPhone]                  VARCHAR (12)  NULL,
    [ValPaymentTypeID]           TINYINT       NULL,
    [CheckAccountNumber]         VARCHAR (4)   NULL,
    [AccountName]                VARCHAR (50)  NULL,
    [ExpirationDate]             DATETIME      NULL,
    [RoutingNumber]              VARCHAR (9)   NULL,
    [BankName]                   VARCHAR (50)  NULL,
    [MembershipMessage]          VARCHAR (100) NULL,
    [ExternalCompanyID]          VARCHAR (20)  NOT NULL,
    [ProcessingStatus]           CHAR (1)      NULL,
    [ProcessingMessage]          VARCHAR (200) NULL,
    [MembershipID]               INT           NULL,
    [ProcessDateTime]            DATETIME      NULL,
    [InsertedDateTime]           DATETIME      NULL,
    [UndiscountedPrice]          MONEY         NULL,
    [PriorPlusPrice]             MONEY         NULL,
    [PriorPlusMembershipTypeID]  INT           NULL,
    [PriorPlusUndiscountedPrice] MONEY         NULL,
    CONSTRAINT [PK_AcquisitionMember] PRIMARY KEY CLUSTERED ([AcquisitionMemberID] ASC)
);

