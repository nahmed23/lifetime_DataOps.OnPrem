CREATE TABLE [dbo].[DSSRAdvisorMembershipTotalsSummary] (
    [DSSRAdvisorMembershipTotalsSummaryID] INT          IDENTITY (1, 1) NOT NULL,
    [MembershipCount]                      INT          NULL,
    [AdvisorFirstName]                     VARCHAR (50) NULL,
    [AdvisorLastName]                      VARCHAR (50) NULL,
    [ClubID]                               INT          NULL,
    [ClubName]                             VARCHAR (50) NULL,
    [DomainNamePrefix]                     VARCHAR (4)  NULL,
    [ValTerminationReasonID]               INT          NULL,
    [ExpirationDate]                       DATETIME     NULL,
    [InsertedDateTime]                     DATETIME     CONSTRAINT [DF_DSSREmployeeMembershipTotalsSummary_ReportDate] DEFAULT (getdate()) NULL,
    [AdvisorEmployeeID]                    INT          NULL,
    CONSTRAINT [PK_DSSREmployeeMembershipTotalsSummary] PRIMARY KEY NONCLUSTERED ([DSSRAdvisorMembershipTotalsSummaryID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_ClubName]
    ON [dbo].[DSSRAdvisorMembershipTotalsSummary]([ClubName] ASC);

