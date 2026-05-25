package com.wealthway.controller;

import com.wealthway.model.Transaction;
import com.wealthway.model.User;
import com.wealthway.service.TransactionService;
import com.wealthway.service.UserService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private static final Logger log = LoggerFactory.getLogger(TransactionController.class);

    private final TransactionService transactionService;
    private final UserService userService;

    // extrage userul din token-ul JWT — nu din body, niciodata din body
    private User getAuthenticatedUser(Authentication auth) {
        return userService.findByEmail(auth.getName())
                .orElseThrow(() -> new RuntimeException("User not found: " + auth.getName()));
    }

    // verifica ca resursa apartine userului care face request-ul
    // daca nu, returneaza 403 si logheaza tentativa
    private ResponseEntity<?> verifyOwnership(Authentication auth, Long ownerId) {
        User caller = getAuthenticatedUser(auth);
        if (!caller.getId().equals(ownerId)) {
            log.warn("[SECURITY] user {} tried to access data of user {}", caller.getId(), ownerId);
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Access denied.");
        }
        return null;
    }

    // GET /api/transactions
    @GetMapping
    public ResponseEntity<?> getAll(Authentication auth) {
        User user = getAuthenticatedUser(auth);
        return ResponseEntity.ok(transactionService.findAllByUser(user));
    }

    // GET /api/transactions/paginated
    @GetMapping("/paginated")
    public ResponseEntity<?> getPaginated(Authentication auth, Pageable pageable) {
        User user = getAuthenticatedUser(auth);
        Page<Transaction> page = transactionService.findByUserPaginated(user, pageable);
        return ResponseEntity.ok(page);
    }

    // GET /api/transactions/type/{type}
    @GetMapping("/type/{type}")
    public ResponseEntity<?> getByType(Authentication auth, @PathVariable String type) {
        User user = getAuthenticatedUser(auth);
        try {
            Transaction.TransactionType txType =
                    Transaction.TransactionType.valueOf(type.toUpperCase());
            return ResponseEntity.ok(transactionService.findByUserAndType(user, txType));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("Invalid type. Accepted: income, expense.");
        }
    }

    // GET /api/transactions/period?startDate=...&endDate=...
    @GetMapping("/period")
    public ResponseEntity<?> getByPeriod(
            Authentication auth,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        User user = getAuthenticatedUser(auth);
        return ResponseEntity.ok(transactionService.findByUserAndPeriod(user, startDate, endDate));
    }

    // GET /api/transactions/monthly-stats/{year}/{month}
    @GetMapping("/monthly-stats/{year}/{month}")
    public ResponseEntity<?> getMonthlyStats(
            Authentication auth,
            @PathVariable int year,
            @PathVariable int month) {
        User user = getAuthenticatedUser(auth);
        TransactionService.MonthlyStats stats =
                transactionService.calculateMonthlyStats(user, year, month);
        return ResponseEntity.ok(stats);
    }

    // GET /api/transactions/by-category
    @GetMapping("/by-category")
    public ResponseEntity<?> getByCategory(
            Authentication auth,
            @RequestParam String type,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        User user = getAuthenticatedUser(auth);
        Transaction.TransactionType txType =
                Transaction.TransactionType.valueOf(type.toUpperCase());
        Map<?, BigDecimal> totals =
                transactionService.calculateTotalByCategory(user, txType, startDate, endDate);
        return ResponseEntity.ok(totals);
    }

    // POST /api/transactions
    @PostMapping
    public ResponseEntity<?> create(Authentication auth, @RequestBody Transaction transaction) {
        try {
            User user = getAuthenticatedUser(auth);
            transaction.setUser(user);
            Transaction saved = transactionService.createTransaction(transaction);
            log.info("[TX] created id={} user={}", saved.getId(), user.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // PUT /api/transactions/{id}
    @PutMapping("/{id}")
    public ResponseEntity<?> update(
            Authentication auth,
            @PathVariable Long id,
            @RequestBody Transaction transaction) {
        try {
            User user = getAuthenticatedUser(auth);
            transaction.setUser(user);
            Transaction updated = transactionService.updateTransaction(id, transaction);
            log.info("[TX] updated id={} user={}", id, user.getId());
            return ResponseEntity.ok(updated);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // DELETE /api/transactions/{id}
    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(Authentication auth, @PathVariable Long id) {
        Transaction existing = transactionService.findById(id)
                .orElseThrow(() -> new RuntimeException("Transaction not found: " + id));
        ResponseEntity<?> check = verifyOwnership(auth, existing.getUser().getId());
        if (check != null) return check;
        transactionService.deleteTransaction(id);
        log.info("[TX] deleted id={}", id);
        return ResponseEntity.noContent().build();
    }
}
