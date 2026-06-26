-- AlterTable
ALTER TABLE "Drug" ADD COLUMN     "outletId" TEXT;

-- AddForeignKey
ALTER TABLE "Drug" ADD CONSTRAINT "Drug_outletId_fkey" FOREIGN KEY ("outletId") REFERENCES "Outlet"("id") ON DELETE SET NULL ON UPDATE CASCADE;
