export interface SemanticAnalysisResult {
  riskScore: number;
  detectedIntents: string[];
  normalizedContent: string;
  leetspeakNormalized: boolean;
  semanticClassifierConfidence: number;
}
