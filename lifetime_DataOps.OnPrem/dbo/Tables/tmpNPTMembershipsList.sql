CREATE TABLE [dbo].[tmpNPTMembershipsList] (
    [MemberID]         INT           NOT NULL,
    [FirstName]        VARCHAR (50)  NULL,
    [LastName]         VARCHAR (50)  NULL,
    [ClubName]         VARCHAR (50)  NULL,
    [MembershipType]   VARCHAR (50)  NULL,
    [EmailAddress]     VARCHAR (140) NULL,
    [Phone]            VARCHAR (50)  NULL,
    [AddressLine1]     VARCHAR (50)  NULL,
    [AddressLine2]     VARCHAR (50)  NULL,
    [City]             VARCHAR (50)  NULL,
    [State]            VARCHAR (3)   NULL,
    [ZIP]              VARCHAR (11)  NULL,
    [JoinDate]         DATETIME      NULL,
    [MembershipSource] VARCHAR (50)  NULL,
    [InsertedDateTime] DATETIME      CONSTRAINT [DF_tmpNPTMembershipsList_InsertedDateTime] DEFAULT (getdate()) NULL
);

