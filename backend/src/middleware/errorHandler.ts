import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  console.error('[ERROR]', err);

  // Zod validation errors
  if (err instanceof ZodError) {
    res.status(400).json({
      error: 'Données invalides',
      details: err.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
    });
    return;
  }

  // Prisma known errors (check via duck-typing for compatibility)
  if ('code' in err && typeof (err as unknown as { code: string }).code === 'string') {
    const prismaErr = err as unknown as { code: string };
    if (prismaErr.code === 'P2002') {
      res.status(409).json({ error: 'Cette ressource existe déjà' });
      return;
    }
    if (prismaErr.code === 'P2025') {
      res.status(404).json({ error: 'Ressource introuvable' });
      return;
    }
    res.status(400).json({ error: 'Erreur base de données' });
    return;
  }

  // Default
  res.status(500).json({ error: 'Erreur interne du serveur' });
}
