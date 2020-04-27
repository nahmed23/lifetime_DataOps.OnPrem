CREATE TABLE [dbo].[MembershipTrack] (
    [MemberShipTrackID] INT      IDENTITY (1, 1) NOT NULL,
    [MembershipID]      INT      NOT NULL,
    [MembershipGroup]   SMALLINT NOT NULL,
    CONSTRAINT [PK_MembershipTrack] PRIMARY KEY NONCLUSTERED ([MemberShipTrackID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_MembershipID]
    ON [dbo].[MembershipTrack]([MembershipID] ASC);

