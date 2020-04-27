CREATE TABLE [dbo].[DSSRSportsNonAccessSummary] (
    [DSSRSportsNonAccessSummaryID] INT          IDENTITY (1, 1) NOT NULL,
    [MembershipID]                 INT          NULL,
    [ActivationDate]               DATETIME     NULL,
    [ExpirationDate]               DATETIME     NULL,
    [CancellationRequestDate]      DATETIME     NULL,
    [MemberID]                     INT          NULL,
    [FirstName]                    VARCHAR (50) NULL,
    [LastName]                     VARCHAR (50) NULL,
    [ClubID]                       INT          NULL,
    [ClubName]                     VARCHAR (50) NULL,
    [InsertedDateTime]             DATETIME     CONSTRAINT [DF_DSSRSportsNonAccessSummary_ReportDate] DEFAULT (getdate()) NULL,
    [Today_Flag]                   BIT          NULL,
    [SignOnDate]                   DATETIME     NULL,
    [TerminationDate]              DATETIME     NULL
);

