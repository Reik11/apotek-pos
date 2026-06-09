-- AlterTable
ALTER TABLE "Drug" ADD COLUMN     "fdaContraindications" TEXT,
ADD COLUMN     "fdaDosage" TEXT,
ADD COLUMN     "fdaIndications" TEXT,
ADD COLUMN     "fdaSideEffects" TEXT,
ADD COLUMN     "fdaWarnings" TEXT,
ADD COLUMN     "lastApiSync" TIMESTAMP(3),
ADD COLUMN     "rxnormIngredients" TEXT,
ADD COLUMN     "rxnormName" TEXT;
