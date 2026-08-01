import Foundation

// MARK: - DeepSeek 余额

/// DeepSeek 平台账户余额（GET https://api.deepseek.com/user/balance）。
struct DeepSeekBalance: Equatable {
    let totalBalance: Double
    let grantedBalance: Double
    let toppedUpBalance: Double
    let currency: String
    let isAvailable: Bool

    /// 余额短格式（菜单栏文本用）：如 12.5 / 0.75 / 120
    var shortText: String {
        if totalBalance >= 100 {
            return String(format: "%.0f", totalBalance)
        }
        if totalBalance >= 10 {
            return String(format: "%.1f", totalBalance)
        }
        return String(format: "%.2f", totalBalance)
    }
}

// MARK: - DeepSeek 服务

/// 查询 DeepSeek 平台余额。token 为 DeepSeek API Key（sk- 前缀），
/// 以 `Authorization: Bearer` 头携带。
final class DeepSeekService {
    func fetchBalance(apiKey: String) async -> Result<DeepSeekBalance, QuotaError> {
        guard !apiKey.isEmpty else {
            return .failure(.invalidKeyFormat)
        }
        guard let url = URL(string: "https://api.deepseek.com/user/balance") else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return .failure(.httpError(statusCode: httpResponse.statusCode, message: body))
                }
                return .failure(.httpError(statusCode: httpResponse.statusCode, message: body))
            }

            struct BalanceInfo: Codable {
                let currency: String
                let totalBalance: String
                let grantedBalance: String
                let toppedUpBalance: String

                enum CodingKeys: String, CodingKey {
                    case currency
                    case totalBalance = "total_balance"
                    case grantedBalance = "granted_balance"
                    case toppedUpBalance = "topped_up_balance"
                }
            }

            struct BalanceResponse: Codable {
                let isAvailable: Bool
                let balanceInfos: [BalanceInfo]

                enum CodingKeys: String, CodingKey {
                    case isAvailable = "is_available"
                    case balanceInfos = "balance_infos"
                }
            }

            let balanceResponse = try JSONDecoder().decode(BalanceResponse.self, from: data)
            let primary = balanceResponse.balanceInfos.first

            return .success(
                DeepSeekBalance(
                    totalBalance: primary.flatMap { Double($0.totalBalance) } ?? 0,
                    grantedBalance: primary.flatMap { Double($0.grantedBalance) } ?? 0,
                    toppedUpBalance: primary.flatMap { Double($0.toppedUpBalance) } ?? 0,
                    currency: primary?.currency ?? "CNY",
                    isAvailable: balanceResponse.isAvailable
                ))
        } catch is DecodingError {
            return .failure(.invalidResponse)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }
}
