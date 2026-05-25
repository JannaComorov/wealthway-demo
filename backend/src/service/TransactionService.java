package com.wealthway.service;

import com.wealthway.model.Category;
import com.wealthway.model.Transaction;
import com.wealthway.model.User;
import com.wealthway.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class TransactionService {

    private final TransactionRepository transactionRepository;

    // READ

    public List<Transaction> findAllByUser(User user) {
        return transactionRepository.findByUserOrderByTransactionDateDesc(user);
    }

    public Page<Transaction> findByUserPaginated(User user, Pageable pageable) {
        return transactionRepository.findByUser(user, pageable);
    }

    public List<Transaction> findByUserAndType(User user, Transaction.TransactionType type) {
        return transactionRepository.findByUserAndTransactionType(user, type);
    }

    public List<Transaction> findByUserAndPeriod(User user, LocalDate start, LocalDate end) {
        return transactionRepository.findByUserAndTransactionDateBetween(user, start, end);
    }

    public Optional<Transaction> findById(Long id) {
        return transactionRepository.findById(id);
    }

    // CREATE
    // userul trebuie setat in controller din token-ul JWT inainte de apel
    public Transaction createTransaction(Transaction transaction) {
        validate(transaction);
        return transactionRepository.save(transaction);
    }

    // UPDATE

    public Transaction updateTransaction(Long id, Transaction details) {
        Transaction existing = transactionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Transaction not found: " + id));

        existing.setCategory(details.getCategory());
        existing.setAmount(details.getAmount());
        existing.setDescription(details.getDescription());
        existing.setTransactionType(details.getTransactionType());
        existing.setTransactionDate(details.getTransactionDate());
        existing.setNotes(details.getNotes());
        existing.setReceiptUrl(details.getReceiptUrl());

        validate(existing);
        return transactionRepository.save(existing);
    }

    // DELETE

    public void deleteTransaction(Long id) {
        if (!transactionRepository.existsById(id)) {
            throw new IllegalArgumentException("Transaction not found: " + id);
        }
        transactionRepository.deleteById(id);
    }

    // AGGREGATIONS

    public BigDecimal calculateTotalIncome(User user, LocalDate start, LocalDate end) {
        BigDecimal result = transactionRepository
                .calculateTotalByUserAndTypeAndDateBetween(user, Transaction.TransactionType.income, start, end);
        return result != null ? result : BigDecimal.ZERO;
    }

    public BigDecimal calculateTotalExpenses(User user, LocalDate start, LocalDate end) {
        BigDecimal result = transactionRepository
                .calculateTotalByUserAndTypeAndDateBetween(user, Transaction.TransactionType.expense, start, end);
        return result != null ? result : BigDecimal.ZERO;
    }

    public BigDecimal calculateBalance(User user, LocalDate start, LocalDate end) {
        return calculateTotalIncome(user, start, end).subtract(calculateTotalExpenses(user, start, end));
    }

    public Map<Category, BigDecimal> calculateTotalByCategory(
            User user, Transaction.TransactionType type, LocalDate start, LocalDate end) {
        return transactionRepository.calculateTotalByCategory(user, type, start, end)
                .stream()
                .collect(Collectors.toMap(
                        row -> (Category) row[0],
                        row -> (BigDecimal) row[1]
                ));
    }

    public MonthlyStats calculateMonthlyStats(User user, int year, int month) {
        LocalDate start = LocalDate.of(year, month, 1);
        LocalDate end   = start.plusMonths(1).minusDays(1);

        BigDecimal income   = calculateTotalIncome(user, start, end);
        BigDecimal expenses = calculateTotalExpenses(user, start, end);

        return new MonthlyStats(income, expenses, income.subtract(expenses));
    }

    public record MonthlyStats(BigDecimal income, BigDecimal expenses, BigDecimal balance) {}

    // VALIDATION

    private void validate(Transaction t) {
        if (t.getUser() == null || t.getUser().getId() == null) {
            throw new IllegalArgumentException("User must be set from JWT token before saving.");
        }
        if (t.getCategory() == null || t.getCategory().getId() == null) {
            throw new IllegalArgumentException("Category is required.");
        }
        if (t.getAmount() == null || t.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Amount must be greater than zero.");
        }
        if (t.getTransactionDate() == null) {
            throw new IllegalArgumentException("Date is required.");
        }
        if (t.getTransactionType() == null) {
            throw new IllegalArgumentException("Type is required: income or expense.");
        }
    }
}
