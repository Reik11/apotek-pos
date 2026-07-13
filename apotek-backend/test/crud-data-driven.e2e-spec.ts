import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { PrismaService } from '../src/modules/prisma/prisma.service';

describe('Drugs CRUD Data-Driven (e2e)', () => {
  jest.setTimeout(180000);
  let app: INestApplication<App>;
  let prisma: PrismaService;
  let authToken: string;
  const createdDrugIds: string[] = [];

  // Generate 30 dummy drug records for data-driven testing
  const dummyDrugs = Array.from({ length: 30 }, (_, index) => {
    const id = index + 1;
    const categories = ['BEBAS', 'BEBAS_TERBATAS', 'KERAS', 'NARKOTIKA', 'PSIKOTROPIKA'];
    const units = ['tablet', 'kapsul', 'botol', 'salep', 'ampul'];
    
    return {
      name: `Obat Dummy ${id}`,
      genericName: `Generik Dummy ${id}`,
      brandName: `Merk Dummy ${id}`,
      activeIngredient: `Bahan Aktif Dummy ${id} 500mg`,
      category: categories[index % categories.length],
      type: 'GENERIK',
      unit: units[index % units.length],
      minStock: 5 + (index * 2),
      sellPrice: 1000 + (index * 500),
      buyPrice: 800 + (index * 400),
      requiresPrescription: (index % 3 === 0),
    };
  });

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();

    prisma = app.get(PrismaService);

    // Ensure we have a valid test user with admin privileges
    const testEmail = `sqa-test-admin-${Date.now()}@test.com`;
    const testPassword = 'sqaPassword123!';

    // Register a new test admin (or bypass OTP for test)
    // To bypass OTP in tests, we can directly create the user in the database using Prisma!
    const user = await prisma.user.create({
      data: {
        name: 'SQA Test Admin',
        email: testEmail,
        password: await require('bcrypt').hash(testPassword, 10),
        role: 'SUPER_ADMIN',
        isActive: true,
      },
    });

    // Login with the created user to get the JWT token
    const loginRes = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ email: testEmail, password: testPassword });

    authToken = loginRes.body.accessToken;

    if (!authToken) {
      throw new Error('Gagal mendapatkan token autentikasi E2E.');
    }
  });

  describe('CRUD Operations (Data-Driven)', () => {
    
    it('Should CREATE 30 drug records (POST /drugs)', async () => {
      for (const drug of dummyDrugs) {
        const response = await request(app.getHttpServer())
          .post('/drugs')
          .set('Authorization', `Bearer ${authToken}`)
          .send(drug);

        expect(response.status).toBe(201);
        expect(response.body).toHaveProperty('id');
        expect(response.body.name).toBe(drug.name);
        
        // Track ID for cleanup and subsequent tests
        createdDrugIds.push(response.body.id);
      }
      expect(createdDrugIds.length).toBe(30);
    });

    it('Should READ all created drug records (GET /drugs)', async () => {
      const response = await request(app.getHttpServer())
        .get('/drugs')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);

      // Verify that all created drugs are present in the list
      createdDrugIds.forEach((id) => {
        const found = response.body.some((drug: any) => drug.id === id);
        expect(found).toBe(true);
      });
    });

    it('Should READ individual drug records by ID (GET /drugs/:id)', async () => {
      for (let i = 0; i < createdDrugIds.length; i++) {
        const id = createdDrugIds[i];
        const originalDrug = dummyDrugs[i];

        const response = await request(app.getHttpServer())
          .get(`/drugs/${id}`)
          .set('Authorization', `Bearer ${authToken}`);

        expect(response.status).toBe(200);
        expect(response.body.id).toBe(id);
        expect(response.body.name).toBe(originalDrug.name);
      }
    });

    it('Should UPDATE all created drug records (PATCH /drugs/:id)', async () => {
      for (let i = 0; i < createdDrugIds.length; i++) {
        const id = createdDrugIds[i];
        const updatedPrice = Math.round(dummyDrugs[i].sellPrice * 1.1); // 10% price increase, rounded to integer

        const response = await request(app.getHttpServer())
          .patch(`/drugs/${id}`)
          .set('Authorization', `Bearer ${authToken}`)
          .send({ sellPrice: updatedPrice });

        expect(response.status).toBe(200);
        expect(response.body.sellPrice).toBe(updatedPrice);
      }
    });

    it('Should DELETE all created drug records (DELETE /drugs/:id)', async () => {
      for (const id of createdDrugIds) {
        const response = await request(app.getHttpServer())
          .delete(`/drugs/${id}`)
          .set('Authorization', `Bearer ${authToken}`);

        expect(response.status).toBe(200);
      }

      // Verify they are deleted
      for (const id of createdDrugIds) {
        const response = await request(app.getHttpServer())
          .get(`/drugs/${id}`)
          .set('Authorization', `Bearer ${authToken}`);

        // drugsService.findOne throws NotFoundException (404) if not found
        expect(response.status).toBe(404);
      }
    });
  });

  afterAll(async () => {
    // Clean up test users
    if (prisma) {
      // Clean up activity logs associated with test users first (FK constraint)
      await prisma.activityLog.deleteMany({
        where: { user: { email: { endsWith: '@test.com' } } },
      });
      
      await prisma.user.deleteMany({
        where: { email: { endsWith: '@test.com' } },
      });
    }

    if (app) {
      await app.close();
    }
  });
});
